// Edge Function: start-match-if-ready
// Authoritative gate into gameplay
// Validates countdown elapsed and transitions match to in_progress

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
  data?: any
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

    const jwt = authHeader.replace('Bearer ', '').trim()

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: `Bearer ${jwt}` }
        },
      }
    )

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: userError } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id } = await req.json()

    if (!match_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: match_id' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get the match with all authoritative fields
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('remote_status, current_player_id, lobby_countdown_started_at, lobby_countdown_seconds, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_voice_ready_at, receiver_voice_ready_at, challenger_id, receiver_id')
      .eq('id', match_id)
      .maybeSingle()

    if (matchError || !match) {
      return new Response(
        JSON.stringify({ error: 'Match not found' } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate user is challenger or receiver
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized for this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Log authoritative state for match start decision
    const matchIdShort = match_id.substring(0, 8)
    const timestamp = new Date().toISOString()
    
    // Event D: START_MATCH_EVAL - evaluating whether match can start
    console.log(`[COUNTDOWN_AUTH] START_MATCH_EVAL match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt evaluator_function=start_match_if_ready`)
    console.log(`[COUNTDOWN_AUTH]   challenger_joined=${match.challenger_lobby_joined_at !== null} receiver_joined=${match.receiver_lobby_joined_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   challenger_voice_ready=${match.challenger_voice_ready_at !== null} receiver_voice_ready=${match.receiver_voice_ready_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   challenger_view_entered=${match.challenger_lobby_joined_at !== null} receiver_view_entered=${match.receiver_lobby_joined_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   countdown_started_at=${match.lobby_countdown_started_at || 'nil'} match_status=${match.remote_status || 'unknown'} current_player_id=${match.current_player_id || 'nil'}`)
    
    // If already in_progress, return success idempotently
    if (match.remote_status === 'in_progress') {
      console.log(`Match ${match_id} already in_progress, returning success`)
      console.log(`[COUNTDOWN_AUTH] START_MATCH_OK match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   decision=already_started reason="match already in_progress"`)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Match already in progress',
          data: { status: 'in_progress' }
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Compute blockers
    const blockers: string[] = []
    if (match.remote_status !== 'lobby') blockers.push('match_not_lobby')
    if (!match.challenger_lobby_joined_at) blockers.push('challenger_joined_false')
    if (!match.receiver_lobby_joined_at) blockers.push('receiver_joined_false')
    if (!match.lobby_countdown_started_at) blockers.push('countdown_not_started')
    
    // Check countdown elapsed
    const countdownDuration = match.lobby_countdown_seconds || 5
    const now = new Date()
    let countdownElapsed = false
    let remainingSeconds = 0
    
    if (match.lobby_countdown_started_at) {
      const countdownStarted = new Date(match.lobby_countdown_started_at)
      const elapsedSeconds = (now.getTime() - countdownStarted.getTime()) / 1000
      countdownElapsed = elapsedSeconds >= countdownDuration
      remainingSeconds = countdownDuration - elapsedSeconds
      if (!countdownElapsed) blockers.push('countdown_not_elapsed')
    }
    
    const decision = blockers.length === 0 ? 'start_match_allowed' : 'start_match_blocked'
    console.log(`[COUNTDOWN_AUTH]   decision=${decision} blockers=[${blockers.join(', ')}]`)
    
    // Validate status is lobby
    if (match.remote_status !== 'lobby') {
      console.log(`[COUNTDOWN_AUTH] START_MATCH_SKIP match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   blockers=[match_not_lobby] reason="match status is ${match.remote_status}, not lobby"`)
      return new Response(
        JSON.stringify({ error: `Match is not in lobby (status: ${match.remote_status})` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate both players present
    if (!match.challenger_lobby_joined_at || !match.receiver_lobby_joined_at) {
      console.log(`[COUNTDOWN_AUTH] START_MATCH_SKIP match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   blockers=[challenger_joined=${match.challenger_lobby_joined_at !== null}, receiver_joined=${match.receiver_lobby_joined_at !== null}] reason="both players must be in lobby"`)
      return new Response(
        JSON.stringify({ error: 'Both players must be in lobby' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate countdown started
    if (!match.lobby_countdown_started_at) {
      console.log(`[COUNTDOWN_AUTH] START_MATCH_SKIP match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   blockers=[countdown_not_started] reason="countdown has not started"`)
      return new Response(
        JSON.stringify({ error: 'Countdown has not started' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate countdown elapsed
    if (!countdownElapsed) {
      console.log(`[COUNTDOWN_AUTH] START_MATCH_SKIP match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   blockers=[countdown_not_elapsed] reason="countdown not elapsed, ${remainingSeconds.toFixed(1)}s remaining"`)
      return new Response(
        JSON.stringify({
          error: 'Countdown not elapsed yet',
          details: { remaining_seconds: remainingSeconds }
        } as ErrorResponse),
        { status: 425, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check not expired/cancelled/completed
    if (match.remote_status === 'expired' || match.remote_status === 'cancelled' || match.remote_status === 'completed') {
      console.log(`[COUNTDOWN_AUTH] START_MATCH_SKIP match=${matchIdShort} timestamp=${timestamp} evaluator_path=start_match_attempt`)
      console.log(`[COUNTDOWN_AUTH]   blockers=[terminal_status] reason="match is ${match.remote_status}"`)
      return new Response(
        JSON.stringify({ error: `Match is ${match.remote_status}` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // All validations passed - transition to in_progress
    const updateData = {
      remote_status: 'in_progress',
      started_at: now.toISOString(),
      current_player_id: match.challenger_id, // Challenger goes first
      updated_at: now.toISOString(),
    }

    const { error: updateError } = await supabaseClient
      .from('matches')
      .update(updateData)
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      console.log(`[COUNTDOWN_AUTH] START_MATCH_ERROR match=${matchIdShort} error=${updateError.message}`)
      return new Response(
        JSON.stringify({ error: 'Failed to start match', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update locks to in_progress
    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .update({ lock_status: 'in_progress' })
      .eq('match_id', match_id)

    if (lockError) {
      console.error('Lock update error:', lockError)
      // Non-fatal - match is already in_progress
    }

    console.log(`✅ Match started: ${match_id}`)
    // Event F: START_MATCH_OK - match successfully transitioned to in_progress
    console.log(`[COUNTDOWN_AUTH] START_MATCH_OK match=${matchIdShort} timestamp=${new Date().toISOString()} evaluator_path=start_match_attempt`)
    console.log(`[COUNTDOWN_AUTH]   decision=start_match_allowed reason="all prerequisites met, countdown elapsed"`)
    console.log(`[COUNTDOWN_AUTH]   current_player_id=${match.challenger_id.substring(0, 8)} new_status=in_progress`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Match started successfully',
        data: {
          status: 'in_progress',
          current_player_id: match.challenger_id
        }
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
