// Edge Function: delete-account
// Permanently deletes the calling user's account and personal data (App Review 5.1.1(v)).
//
// Behavior:
//   - Revokes the user's Apple refresh token if present (best-effort).
//   - Deletes solo/guest local matches (cascades match_players/match_throws); anonymizes
//     local matches shared with another registered user (keeps match, nulls created_by).
//   - Cleans up rows not covered by FK cascade (remote_match_locks, push_delivery_log).
//   - Deletes the auth user via the service role, which cascades public.users.
//     In SHARED remote matches, match_players.player_user_id -> SET NULL and
//     winner_id -> SET NULL (migration 087), while challenger_id/receiver_id are left
//     as stale UUIDs (client renders "Deleted User"), preserving opponents' history.
//
// Requires function env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// Optional (for Apple revocation): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_BUNDLE_ID

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---------------------------------------------------------------------------
// Sign in with Apple revocation (inlined so this function deploys as a single
// file via the Supabase dashboard). Requires env: APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_PRIVATE_KEY (.p8 PEM), APPLE_BUNDLE_ID.
// ---------------------------------------------------------------------------
const APPLE_TEAM_ID = Deno.env.get('APPLE_TEAM_ID') ?? ''
const APPLE_KEY_ID = Deno.env.get('APPLE_KEY_ID') ?? ''
const APPLE_PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY') ?? ''
const APPLE_BUNDLE_ID = Deno.env.get('APPLE_BUNDLE_ID') ?? ''
const APPLE_REVOKE_URL = 'https://appleid.apple.com/auth/revoke'

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

async function revokeAppleToken(refreshToken: string): Promise<boolean> {
  const clientSecret = await createAppleClientSecret()
  const body = new URLSearchParams({
    client_id: APPLE_BUNDLE_ID,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  })
  const res = await fetch(APPLE_REVOKE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  })
  if (!res.ok) {
    console.error(`[apple] revoke failed: ${res.status} ${await res.text()}`)
    return false
  }
  return true
}

interface ErrorResponse {
  error: string
  details?: any
}

interface SuccessResponse {
  success: boolean
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

    // Caller-scoped client: used only to authenticate and resolve the user id.
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

    const uid = user.id

    // Service-role client: performs privileged deletion (bypasses RLS).
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    console.log(`[delete-account] START uid=${uid}`)

    // -------------------------------------------------
    // 1) Apple token revocation (best-effort; never blocks deletion)
    // -------------------------------------------------
    try {
      const { data: appleRow } = await supabaseAdmin
        .from('apple_auth_tokens')
        .select('refresh_token')
        .eq('user_id', uid)
        .maybeSingle()

      if (appleRow?.refresh_token) {
        if (appleConfigured()) {
          const ok = await revokeAppleToken(appleRow.refresh_token)
          console.log(`[delete-account] apple revoke: ${ok ? 'ok' : 'failed (non-fatal)'}`)
        } else {
          console.log('[delete-account] apple secrets not configured - skipping revoke')
        }
      }
    } catch (e) {
      console.error('[delete-account] apple revoke error (non-fatal):', e)
    }

    // -------------------------------------------------
    // 2) Handle the user's LOCAL matches:
    //      - Solo / user+guest local matches   -> DELETE (cascades players/throws).
    //      - Local matches shared with ANOTHER registered user -> ANONYMIZE: keep the
    //        match, null created_by; the user's match_players row is SET NULL by the
    //        auth-user delete cascade below. Preserves the co-player's history.
    //    We NEVER touch local matches created by a DIFFERENT user (only their own +
    //    ownerless ones they played in are candidates). Remote matches are always
    //    preserved and anonymized via FK SET NULL.
    // -------------------------------------------------
    const candidateIds = new Set<string>()

    // 2a) Local matches created by the user.
    const { data: createdLocal, error: createdErr } = await supabaseAdmin
      .from('matches')
      .select('id')
      .eq('match_mode', 'local')
      .eq('created_by', uid)
    if (createdErr) console.error('[delete-account] createdLocal query error:', createdErr)
    createdLocal?.forEach((m: any) => candidateIds.add(m.id))

    // 2b) OWNERLESS local matches (created_by IS NULL) where the user is a player.
    const { data: playerRows, error: playerErr } = await supabaseAdmin
      .from('match_players')
      .select('match_id')
      .eq('player_user_id', uid)
    if (playerErr) console.error('[delete-account] playerRows query error:', playerErr)

    const playerMatchIds = (playerRows ?? []).map((r: any) => r.match_id)
    if (playerMatchIds.length > 0) {
      const { data: ownerlessLocal, error: ownerlessErr } = await supabaseAdmin
        .from('matches')
        .select('id')
        .eq('match_mode', 'local')
        .is('created_by', null)
        .in('id', playerMatchIds)
      if (ownerlessErr) console.error('[delete-account] ownerlessLocal query error:', ownerlessErr)
      ownerlessLocal?.forEach((m: any) => candidateIds.add(m.id))
    }

    // 2c) Classify candidates: does the match have ANOTHER registered user as a player?
    const toDelete: string[] = []
    const toAnonymize: string[] = []
    if (candidateIds.size > 0) {
      const ids = Array.from(candidateIds)
      const { data: allPlayers, error: allPlayersErr } = await supabaseAdmin
        .from('match_players')
        .select('match_id, player_user_id')
        .in('match_id', ids)
      if (allPlayersErr) console.error('[delete-account] classify players query error:', allPlayersErr)

      const hasOtherRegisteredUser = new Set<string>()
      ;(allPlayers ?? []).forEach((r: any) => {
        if (r.player_user_id && r.player_user_id !== uid) hasOtherRegisteredUser.add(r.match_id)
      })
      for (const id of ids) {
        if (hasOtherRegisteredUser.has(id)) toAnonymize.push(id)
        else toDelete.push(id)
      }
    }

    // 2d) Delete solo/guest local matches (cascades match_players / match_throws).
    if (toDelete.length > 0) {
      const { error: delMatchesErr } = await supabaseAdmin
        .from('matches')
        .delete()
        .in('id', toDelete)
      if (delMatchesErr) {
        console.error('[delete-account] local match delete error:', delMatchesErr)
        return new Response(
          JSON.stringify({ error: 'Failed to delete local matches', details: delMatchesErr } as ErrorResponse),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      console.log(`[delete-account] deleted ${toDelete.length} solo/guest local match(es)`)
    }

    // 2e) Anonymize local matches shared with another registered user: null created_by
    //     so nothing points at the deleted user. The user's match_players.player_user_id
    //     is SET NULL by the auth-user delete cascade below.
    if (toAnonymize.length > 0) {
      const { error: anonErr } = await supabaseAdmin
        .from('matches')
        .update({ created_by: null })
        .in('id', toAnonymize)
      if (anonErr) console.error('[delete-account] anonymize created_by error (non-fatal):', anonErr)
      console.log(`[delete-account] anonymized ${toAnonymize.length} shared local match(es)`)
    }

    // -------------------------------------------------
    // 3) Cleanup rows not covered by FK cascade.
    // -------------------------------------------------
    const { error: lockErr } = await supabaseAdmin
      .from('remote_match_locks')
      .delete()
      .eq('user_id', uid)
    if (lockErr) console.error('[delete-account] remote_match_locks cleanup error (non-fatal):', lockErr)

    const { error: pushLogErr } = await supabaseAdmin
      .from('push_delivery_log')
      .delete()
      .eq('recipient_user_id', uid)
    if (pushLogErr) console.error('[delete-account] push_delivery_log cleanup error (non-fatal):', pushLogErr)

    // -------------------------------------------------
    // 4) Delete the auth user. Cascades public.users -> friendships / push_tokens /
    //    invites / apple_auth_tokens; SET NULLs shared remote-match identity columns
    //    and match_players.player_user_id (anonymization).
    // -------------------------------------------------
    const { error: deleteUserErr } = await supabaseAdmin.auth.admin.deleteUser(uid)
    if (deleteUserErr) {
      console.error('[delete-account] auth deleteUser error:', deleteUserErr)
      return new Response(
        JSON.stringify({ error: 'Failed to delete account', details: deleteUserErr } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[delete-account] SUCCESS uid=${uid}`)

    return new Response(
      JSON.stringify({ success: true, message: 'Account deleted' } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[delete-account] Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
