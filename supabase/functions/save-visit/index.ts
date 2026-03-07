// Edge Function: save-visit
// Saves a visit (3 darts) for a remote match with server-side validation
// ✅ PATCH: Handle rpcResult being ARRAY vs OBJECT
// ✅ PATCH: Add SERVICE ROLE client for debug verification
// ✅ PATCH: After RPC, query match_throws count + latest row for this match_id
// ✅ PATCH: Fail loudly if throws still 0 (so the client cannot think it succeeded)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) {
      return new Response(JSON.stringify({ error: 'Invalid Authorization header' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const url = Deno.env.get('SUPABASE_URL') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // User-scoped client (keeps current behavior)
    const supabaseClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    // Service-role client (DEBUG ONLY — do not expose to client; only used server-side)
    const supabaseAdmin = createClient(url, serviceKey)

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(jwt)
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized', details: userError }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { match_id, darts, score_before, score_after } = await req.json()
    if (!match_id || !darts || score_before === undefined || score_after === undefined) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (!Array.isArray(darts) || darts.length !== 3) {
      return new Response(JSON.stringify({ error: 'Darts must be an array of 3 scores' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Fetch match (user-scoped)
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', match_id)
      .maybeSingle()

    if (matchError || !match) {
      return new Response(JSON.stringify({ error: 'Match not found', details: matchError }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not authorized for this match' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (match.remote_status !== 'in_progress') {
      return new Response(JSON.stringify({ error: 'Match is not in progress', status: match.remote_status }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (match.current_player_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Not your turn', current_player_id: match.current_player_id }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const nowIso = new Date().toISOString()

    console.log('[save-visit] rpc save_remote_visit args', {
      match_id, player_id: user.id, darts, score_before, score_after, nowIso
    })

    const { data, error: rpcError } = await supabaseClient.rpc('save_remote_visit', {
      p_match_id: match_id,
      p_player_id: user.id,
      p_throws: darts,
      p_score_before: score_before,
      p_score_after: score_after,
      p_is_bust: false,
      p_timestamp: nowIso,
    })

    if (rpcError) {
      console.error('[save-visit] RPC FAILED', rpcError)
      return new Response(JSON.stringify({ error: 'Failed to save visit', details: rpcError }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ✅ IMPORTANT: normalize result (PostgREST often returns an array)
    const rpcResult = Array.isArray(data) ? data[0] : data
    console.log('[save-visit] RPC OK raw=', data)
    console.log('[save-visit] RPC OK normalized=', rpcResult)

    // ✅ DEBUG VERIFY: check match_throws using service role
    const { count: throwCount, error: countErr } = await supabaseAdmin
      .from('match_throws')
      .select('*', { count: 'exact', head: true })
      .eq('match_id', match_id)

    if (countErr) {
      console.error('[save-visit] DEBUG count match_throws FAILED', countErr)
      return new Response(JSON.stringify({ error: 'Debug count failed', details: countErr }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: latestThrow, error: latestErr } = await supabaseAdmin
      .from('match_throws')
      .select('*')
      .eq('match_id', match_id)
      .order('created_at', { ascending: false })
      .limit(1)

    if (latestErr) console.error('[save-visit] DEBUG latest match_throws FAILED', latestErr)

    console.log('[save-visit] DEBUG match_throws count=', throwCount)
    console.log('[save-visit] DEBUG latest throw=', latestThrow?.[0] ?? null)

    // 🚨 If we still have 0 rows, DO NOT return success — force it to fail loudly
    if ((throwCount ?? 0) === 0) {
      return new Response(JSON.stringify({
        error: 'RPC returned success but match_throws still has 0 rows (insert did not happen)',
        rpcResult,
      }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Use normalized rpcResult safely
    const status = rpcResult?.status

    if (status === 'completed') {
      return new Response(JSON.stringify({
        success: true,
        data: {
          winner_id: rpcResult?.winner_id ?? null,
          status: 'completed',
          debug_throw_count: throwCount,
          debug_latest_throw: latestThrow?.[0] ?? null,
        },
        message: 'Match completed',
      }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        next_player_id: rpcResult?.next_player_id ?? null,
        turn_index_in_leg: rpcResult?.turn_index ?? null,
        debug_throw_count: throwCount,
        debug_latest_throw: latestThrow?.[0] ?? null,
      },
      message: 'Visit saved successfully',
    }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('[save-visit] Unexpected error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error', details: String(error) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
