// Edge Function: exchange-apple-code
// Exchanges a Sign in with Apple authorization code for a long-lived refresh token
// and stores it (server-only) so the account can be revoked at deletion time.
//
// Why: the Apple authorization code expires in ~5 minutes, so it must be exchanged
// immediately at sign-in. The resulting refresh token is stored in apple_auth_tokens
// (RLS: no client access) and later revoked by delete-account (App Review 5.1.1).
//
// Requires function env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_BUNDLE_ID

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---------------------------------------------------------------------------
// Sign in with Apple code exchange (inlined so this function deploys as a single
// file via the Supabase dashboard). Requires env: APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_PRIVATE_KEY (.p8 PEM), APPLE_BUNDLE_ID.
// ---------------------------------------------------------------------------
const APPLE_TEAM_ID = Deno.env.get('APPLE_TEAM_ID') ?? ''
const APPLE_KEY_ID = Deno.env.get('APPLE_KEY_ID') ?? ''
const APPLE_PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY') ?? ''
const APPLE_BUNDLE_ID = Deno.env.get('APPLE_BUNDLE_ID') ?? ''
const APPLE_TOKEN_URL = 'https://appleid.apple.com/auth/token'

function appleConfigured(): boolean {
  return !!(APPLE_TEAM_ID && APPLE_KEY_ID && APPLE_PRIVATE_KEY && APPLE_BUNDLE_ID)
}

function base64UrlFromString(input: string): string {
  return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function base64UrlFromBytes(bytes: Uint8Array): string {
  let str = ''
  for (const b of bytes) str += String.fromCharCode(b)
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToPkcs8Bytes(pem: string): Uint8Array {
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const binary = atob(body)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

async function createAppleClientSecret(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'ES256', kid: APPLE_KEY_ID, typ: 'JWT' }
  const payload = {
    iss: APPLE_TEAM_ID,
    iat: now,
    exp: now + 300,
    aud: 'https://appleid.apple.com',
    sub: APPLE_BUNDLE_ID,
  }
  const signingInput =
    `${base64UrlFromString(JSON.stringify(header))}.${base64UrlFromString(JSON.stringify(payload))}`
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8Bytes(APPLE_PRIVATE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )
  return `${signingInput}.${base64UrlFromBytes(new Uint8Array(signature))}`
}

async function exchangeAppleCode(code: string): Promise<string | null> {
  const clientSecret = await createAppleClientSecret()
  const body = new URLSearchParams({
    client_id: APPLE_BUNDLE_ID,
    client_secret: clientSecret,
    code,
    grant_type: 'authorization_code',
  })
  const res = await fetch(APPLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  })
  if (!res.ok) {
    console.error(`[apple] token exchange failed: ${res.status} ${await res.text()}`)
    return null
  }
  const json = await res.json()
  return (json?.refresh_token as string | undefined) ?? null
}

interface ErrorResponse {
  error: string
  details?: any
}

interface SuccessResponse {
  success: boolean
  stored: boolean
  message: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'Invalid Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { authorization_code } = await req.json().catch(() => ({}))
    if (!authorization_code || typeof authorization_code !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Missing required field: authorization_code' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // If Apple secrets aren't configured, succeed without storing (non-blocking to sign-in).
    if (!appleConfigured()) {
      console.log('[exchange-apple-code] apple secrets not configured - skipping (non-fatal)')
      return new Response(
        JSON.stringify({ success: true, stored: false, message: 'Apple not configured' } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const refreshToken = await exchangeAppleCode(authorization_code)
    if (!refreshToken) {
      // Non-fatal: sign-in should still succeed even if we couldn't store a revoke token.
      console.error('[exchange-apple-code] exchange returned no refresh token')
      return new Response(
        JSON.stringify({ success: true, stored: false, message: 'No refresh token returned' } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { error: upsertError } = await supabaseAdmin
      .from('apple_auth_tokens')
      .upsert(
        { user_id: user.id, refresh_token: refreshToken, updated_at: new Date().toISOString() },
        { onConflict: 'user_id' }
      )

    if (upsertError) {
      console.error('[exchange-apple-code] store error:', upsertError)
      return new Response(
        JSON.stringify({ error: 'Failed to store Apple token', details: upsertError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[exchange-apple-code] stored refresh token for uid=${user.id}`)
    return new Response(
      JSON.stringify({ success: true, stored: true, message: 'Stored' } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[exchange-apple-code] Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
