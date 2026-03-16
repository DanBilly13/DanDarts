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

    // Get the match
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

    // Validate user is challenger or receiver
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized for this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // If already in_progress, return success idempotently
    if (match.remote_status === 'in_progress') {
      console.log(`Match ${match_id} already in_progress, returning success`)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Match already in progress',
          data: { status: 'in_progress' }
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate status is lobby
    if (match.remote_status !== 'lobby') {
      return new Response(
        JSON.stringify({ error: `Match is not in lobby (status: ${match.remote_status})` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate both players present
    if (!match.challenger_lobby_joined_at || !match.receiver_lobby_joined_at) {
      return new Response(
        JSON.stringify({ error: 'Both players must be in lobby' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate countdown started
    if (!match.lobby_countdown_started_at) {
      return new Response(
        JSON.stringify({ error: 'Countdown has not started' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate countdown elapsed
    const countdownDuration = match.lobby_countdown_seconds || 5
    const countdownStarted = new Date(match.lobby_countdown_started_at)
    const now = new Date()
    const elapsedSeconds = (now.getTime() - countdownStarted.getTime()) / 1000

    if (elapsedSeconds < countdownDuration) {
      const remainingSeconds = countdownDuration - elapsedSeconds
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
