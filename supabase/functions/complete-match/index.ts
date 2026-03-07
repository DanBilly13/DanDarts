// Edge Function: complete-match
// Completes a match that has finished naturally (winner detected)
// This is DIFFERENT from abort-match (user-initiated) and cancel-match (pre-game).
//
// Key Design Goals:
// - Idempotent (safe to call multiple times)
// - Server-authoritative completion
// - Emits realtime UPDATE so both clients see completion
// - Clears any match locks
// - Guards against terminal state corruption
// - Records winner_id for match history

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

    console.log("🏆 [CompleteMatch] authHeader exists:", !!authHeader)
    console.log("🏆 [CompleteMatch] authHeader prefix:", authHeader?.slice(0, 20))
    console.log("🏆 [CompleteMatch] jwt length:", jwt?.length)

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      console.error("🏆 [CompleteMatch] getUser error:", userError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id, winner_id } = await req.json()

    if (!match_id) {
      return new Response(
        JSON.stringify({ error: 'Missing match_id' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!winner_id) {
      return new Response(
        JSON.stringify({ error: 'Missing winner_id' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Normalize UUIDs to lowercase (Swift sends uppercase, PostgreSQL stores lowercase)
    const normalizedMatchId = match_id.toLowerCase()
    const normalizedWinnerId = winner_id.toLowerCase()

    console.log(`🏆 [CompleteMatch] Request - matchId: ${normalizedMatchId}, winnerId: ${normalizedWinnerId}, userId: ${user.id}`)

    // Fetch match
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', normalizedMatchId)
      .maybeSingle()

    if (matchError || !match) {
      console.error("🏆 [CompleteMatch] Match not found:", matchError)
      return new Response(
        JSON.stringify({ error: 'Match not found' } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate membership
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      console.error(`🏆 [CompleteMatch] User ${user.id} not authorized for match ${match_id}`)
      return new Response(
        JSON.stringify({ error: 'Not authorized to complete this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate winner is a participant
    if (match.challenger_id !== normalizedWinnerId && match.receiver_id !== normalizedWinnerId) {
      console.error(`🏆 [CompleteMatch] Winner ${normalizedWinnerId} is not a participant in match ${normalizedMatchId}`)
      return new Response(
        JSON.stringify({ error: 'Winner must be a participant in the match' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // -------------------------------
    // 1️⃣ Idempotency check FIRST
    // -------------------------------
    // If already in ANY terminal state, return success.
    // This prevents race-condition failures.
    if (match.remote_status === 'cancelled' || match.remote_status === 'completed') {
      console.log(`✅ [CompleteMatch] Match already in terminal state: ${match.remote_status}`)
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
    // Complete is only allowed for in_progress matches
    if (match.remote_status !== 'in_progress') {
      console.error(`🏆 [CompleteMatch] Cannot complete match in state: ${match.remote_status}`)
      return new Response(
        JSON.stringify({
          error: 'Cannot complete match in this state',
          details: `Current status: ${match.remote_status}. Only in_progress matches can be completed.`,
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
        remote_status: 'completed',
        winner_id: normalizedWinnerId,
        ended_at: now,
        ended_by: user.id,
        ended_reason: 'completed',
        updated_at: now,
      })
      .eq('id', normalizedMatchId)
      .in('remote_status', ['in_progress']) // Prevent terminal state corruption
      .select('id, remote_status, winner_id')
      .single()

    if (updateError || !updatedMatch) {
      // Check if update failed because match transitioned to terminal state
      const { data: currentMatch } = await supabaseClient
        .from('matches')
        .select('remote_status')
        .eq('id', normalizedMatchId)
        .single()
      
      if (currentMatch?.remote_status === 'cancelled' || currentMatch?.remote_status === 'completed') {
        // Race condition: match became terminal between our check and update
        console.log(`✅ [CompleteMatch] Match transitioned to terminal state during update: ${currentMatch.remote_status}`)
        return new Response(
          JSON.stringify({
            success: true,
            message: `Match already ${currentMatch.remote_status}`,
          } as SuccessResponse),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.error("🏆 [CompleteMatch] Update failed:", updateError)
      return new Response(
        JSON.stringify({
          error: 'Failed to complete match',
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
      .eq('match_id', normalizedMatchId)

    if (lockError) {
      console.error('🏆 [CompleteMatch] Lock cleanup failed:', lockError)
      // Do not fail request — match is already completed
    } else {
      console.log(`🏆 [CompleteMatch] Lock cleared for match ${normalizedMatchId}`)
    }

    console.log(`✅ [CompleteMatch] Match completed: ${normalizedMatchId}, winner: ${normalizedWinnerId}, by user: ${user.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Match completed successfully',
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('🏆 [CompleteMatch] Unexpected error:', error)

    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error',
      } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
