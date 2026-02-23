// Edge Function: abort-match
// Aborts a match that has already started (lobby or in_progress)
// This is DIFFERENT from cancel-match, which handles pending/ready states.
//
// Key Design Goals:
// - Idempotent (safe to call multiple times)
// - Server-authoritative termination
// - Emits realtime UPDATE so both clients exit lobby/gameplay
// - Clears any match locks
// - Guards against terminal state corruption

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

  // Strict method enforcement
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  try {
    const authHeader = req.headers.get('Authorization')

    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Extract JWT token from Bearer header
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
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    console.log("authHeader exists:", !!authHeader)
    console.log("authHeader prefix:", authHeader?.slice(0, 20))
    console.log("jwt length:", jwt?.length)

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      console.error("getUser error:", userError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id } = await req.json()

    if (!match_id) {
      return new Response(
        JSON.stringify({ error: 'Missing match_id' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch match
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', match_id)
      .maybeSingle()

    if (matchError || !match) {
      return new Response(
        JSON.stringify({ error: 'Match not found' } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate membership
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to abort this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // -------------------------------
    // 1️⃣ Idempotency check FIRST
    // -------------------------------
    // If already in ANY terminal state, return success.
    // This prevents race-condition failures.
    if (match.remote_status === 'cancelled' || match.remote_status === 'completed') {
      console.log(`✅ Match already in terminal state: ${match.remote_status}`)
      return new Response(
        JSON.stringify({
          success: true,
          message: `Match already ${match.remote_status}`,
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // -------------------------------
    // 2️⃣ Validate allowed states
    // -------------------------------
    // Abort is only allowed for active match states
    if (
      match.remote_status !== 'lobby' &&
      match.remote_status !== 'in_progress' &&
      match.remote_status !== 'ready'
    ) {
      return new Response(
        JSON.stringify({
          error: 'Cannot abort match in this state',
          details: `Current status: ${match.remote_status}. Use cancel-match for pending/sent states.`,
        } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date().toISOString()

    // -------------------------------
    // 3️⃣ Update match with terminal state guard
    // -------------------------------
    // Guard against terminal state corruption with .in()
    const { data: updatedMatch, error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'cancelled',
        ended_at: now,
        ended_by: user.id,
        ended_reason: 'aborted',
        updated_at: now,
      })
      .eq('id', match_id)
      .in('remote_status', ['lobby', 'in_progress', 'ready']) // Prevent terminal state corruption
      .select('id, remote_status')
      .single()

    if (updateError || !updatedMatch) {
      // Check if update failed because match transitioned to terminal state
      const { data: currentMatch } = await supabaseClient
        .from('matches')
        .select('remote_status')
        .eq('id', match_id)
        .single()
      
      if (currentMatch?.remote_status === 'cancelled' || currentMatch?.remote_status === 'completed') {
        // Race condition: match became terminal between our check and update
        console.log(`✅ Match transitioned to terminal state during update: ${currentMatch.remote_status}`)
        return new Response(
          JSON.stringify({
            success: true,
            message: `Match already ${currentMatch.remote_status}`,
          } as SuccessResponse),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      return new Response(
        JSON.stringify({
          error: 'Failed to abort match',
          details: updateError?.message || 'Update returned no data',
        } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // -------------------------------
    // 4️⃣ Clear locks (non-fatal)
    // -------------------------------
    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .delete()
      .eq('match_id', match_id)

    if (lockError) {
      console.error('Lock cleanup failed:', lockError)
      // Do not fail request — match is already cancelled
    }

    console.log(`✅ Match aborted: ${match_id} by ${user.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Match aborted successfully',
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Unexpected error:', error)

    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error',
      } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
