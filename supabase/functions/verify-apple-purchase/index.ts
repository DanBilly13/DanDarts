// Edge Function: verify-apple-purchase
// Records a DartFreak Full purchase made on iOS against the calling user's account, so the
// unlock follows them to Android. Looks the transaction up with Apple's App Store Server API
// (rather than trusting the app), checks it is our unlock and not refunded, then upserts
// public.user_entitlements with the service role.
//
// Requires env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//   ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY (In-App Purchase .p8 key, PEM), APPLE_BUNDLE_ID
// Optional (testing only): APPLE_ALLOW_SANDBOX=true accepts sandbox/TestFlight/Xcode transactions

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const PRODUCT_ID = 'com.dandarts.DartFreak.full'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function base64Url(bytes: Uint8Array): string {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)))
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0)).buffer
}

// ES256 JWT for the App Store Server API (valid 5 minutes).
async function appStoreServerToken(): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(Deno.env.get('ASC_PRIVATE_KEY') ?? ''),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const now = Math.floor(Date.now() / 1000)
  const header = base64UrlJson({ alg: 'ES256', kid: Deno.env.get('ASC_KEY_ID'), typ: 'JWT' })
  const payload = base64UrlJson({
    iss: Deno.env.get('ASC_ISSUER_ID'),
    iat: now,
    exp: now + 300,
    aud: 'appstoreconnect-v1',
    bid: Deno.env.get('APPLE_BUNDLE_ID'),
  })
  // WebCrypto ECDSA returns raw r||s, which is exactly what JWS ES256 needs.
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )
  return `${header}.${payload}.${base64Url(new Uint8Array(signature))}`
}

// The response comes straight from Apple over TLS with our credentials, so the
// signed payload can be decoded without re-verifying Apple's certificate chain.
function decodeJwsPayload(jws: string): Record<string, unknown> {
  const part = jws.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
  const padded = part + '='.repeat((4 - (part.length % 4)) % 4)
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (c) => c.charCodeAt(0))))
}

// Production first; a 404 there means it may be a sandbox (TestFlight / Xcode) purchase.
async function fetchTransaction(transactionId: string): Promise<Record<string, unknown> | null> {
  const token = await appStoreServerToken()
  const hosts = ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com']
  for (const host of hosts) {
    const res = await fetch(`${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    if (res.status === 404) {
      const errBody = await res.json().catch(() => null)
      if (errBody?.errorCode === 4040010) continue // TransactionIdNotFound: try sandbox
      throw new Error(`App Store Server API 404 errorCode=${errBody?.errorCode ?? 'unknown'}`)
    }
    if (!res.ok) throw new Error(`App Store Server API returned ${res.status}`)
    const body = await res.json()
    return decodeJwsPayload(body.signedTransactionInfo)
  }
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const authHeader = req.headers.get('Authorization') ?? ''
    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) return json(401, { error: 'not_authenticated' })

    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: userError } = await userClient.auth.getUser(jwt)
    if (userError || !user) return json(401, { error: 'not_authenticated' })

    const body = await req.json().catch(() => null)
    const transaction_id = body?.transaction_id
    if (typeof transaction_id !== 'string' || !/^\d+$/.test(transaction_id)) {
      return json(400, { error: 'invalid_transaction_id' })
    }

    const tx = await fetchTransaction(transaction_id)
    if (!tx) return json(404, { error: 'transaction_not_found' })
    if (
      tx.bundleId !== Deno.env.get('APPLE_BUNDLE_ID') || tx.productId !== PRODUCT_ID || tx.revocationDate ||
      typeof tx.originalTransactionId !== 'string'
    ) {
      return json(403, { error: 'not_a_valid_unlock' })
    }
    if (tx.environment !== 'Production' && Deno.env.get('APPLE_ALLOW_SANDBOX') !== 'true') {
      return json(403, { error: 'sandbox_not_allowed' })
    }
    if (typeof tx.appAccountToken === 'string' && tx.appAccountToken.toLowerCase() !== user.id.toLowerCase()) {
      return json(403, { error: 'account_mismatch' })
    }

    const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Keep an existing Google or manual grant: overwriting it with an Apple row would hide it
    // from iOS (which ignores apple rows) and lose where the unlock came from.
    const { data: existing, error: existingError } = await admin
      .from('user_entitlements')
      .select('source')
      .eq('user_id', user.id)
      .maybeSingle()
    if (existingError) throw existingError
    if (existing && existing.source !== 'apple') {
      return json(200, { ok: true, kept: existing.source })
    }

    const { error } = await admin.from('user_entitlements').upsert(
      {
        user_id: user.id,
        source: 'apple',
        store_transaction_id: String(tx.originalTransactionId),
        granted_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' },
    )
    if (error) {
      if (error.code === '23505') return json(409, { error: 'purchase_linked_to_another_account' })
      throw error
    }

    console.log(`✅ [verify-apple-purchase] entitlement recorded for ${user.id}`)
    return json(200, { ok: true })
  } catch (err) {
    console.error('❌ [verify-apple-purchase]', err)
    return json(500, { error: 'internal' })
  }
})
