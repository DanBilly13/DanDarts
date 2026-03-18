// Edge Function: enter-lobby
// Dedicated server action for entering the lobby
// Sets lobby presence timestamps and manages lobby state transitions

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

  const requestStart = Date.now()
  let matchId = 'unknown'
  
  try {
    console.log(`[TIMING] enter-lobby | step=request_received | ts=${new Date().toISOString()}`)
    
    const authHeader = req.headers.get('Authorization')
    
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const jwt = authHeader.replace('Bearer ', '').trim()

    const authStart = Date.now()
    console.log(`[TIMING] enter-lobby | step=auth_start | ts=${new Date().toISOString()}`)
    
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
    
    const authDuration = Date.now() - authStart
    console.log(`[TIMING] enter-lobby | step=auth_end | duration_ms=${authDuration}`)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: userError } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id } = await req.json()
    matchId = match_id || 'unknown'
    // console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=body_parsed`)

    if (!match_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: match_id' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get the match
    const matchSelectStart = Date.now()
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=match_select_start | ts=${new Date().toISOString()}`)
    
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', match_id)
      .maybeSingle()
    
    const matchSelectDuration = Date.now() - matchSelectStart
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=match_select_end | duration_ms=${matchSelectDuration}`)

    if (matchError || !match) {
      console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=match_not_found | error=${JSON.stringify(matchError)}`)
      return new Response(
        JSON.stringify({ error: 'Match not found' } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate user is challenger or receiver
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to join this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate status is ready or lobby
    if (match.remote_status !== 'ready' && match.remote_status !== 'lobby') {
      return new Response(
        JSON.stringify({ error: `Match is not joinable (status: ${match.remote_status})` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check not expired
    if (match.join_window_expires_at && new Date(match.join_window_expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Join window has expired' } as ErrorResponse),
        { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()

    // Determine which player is joining
    const isChallenger = match.challenger_id === user.id
    const lobbyTimestampField = isChallenger ? 'challenger_lobby_joined_at' : 'receiver_lobby_joined_at'
    const otherLobbyTimestampField = isChallenger ? 'receiver_lobby_joined_at' : 'challenger_lobby_joined_at'

    // Check if this player already joined (idempotency)
    if (match[lobbyTimestampField]) {
      // console.log(`Player ${user.id} already in lobby, returning success`)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Already in lobby',
          data: { status: match.remote_status }
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build update data
    const updateData: any = {
      [lobbyTimestampField]: now.toISOString(),
      updated_at: now.toISOString(),
    }

    // If first player enters, transition to lobby
    if (match.remote_status === 'ready') {
      updateData.remote_status = 'lobby'
      // console.log('First player entering lobby - transitioning to lobby status')
    }

    // Check if both players are now present
    const otherPlayerPresent = match[otherLobbyTimestampField] !== null
    const bothPlayersPresent = otherPlayerPresent

    // Note: Countdown is now started by confirm-lobby-view-entered
    // when both players have actually entered the lobby UI
    // console.log(`Both players present: ${bothPlayersPresent} (countdown will start when both confirm lobby view entered)`)

    // Update match
    const matchUpdateStart = Date.now()
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=match_update_start | ts=${new Date().toISOString()} | updateData=${JSON.stringify(updateData)}`)
    
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update(updateData)
      .eq('id', match_id)
    
    const matchUpdateDuration = Date.now() - matchUpdateStart
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=match_update_end | duration_ms=${matchUpdateDuration} | error=${updateError ? JSON.stringify(updateError) : 'null'}`)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to enter lobby', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create match_player record for this user if not exists
    const playerOrder = user.id === match.challenger_id ? 0 : 1
    const playerUpsertStart = Date.now()
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=player_upsert_start | ts=${new Date().toISOString()} | playerOrder=${playerOrder}`)
    
    const { error: playerInsertError } = await supabaseClient
      .from('match_players')
      .upsert({
        match_id: match_id,
        player_user_id: user.id,
        player_order: playerOrder,
      }, {
        onConflict: 'match_id,player_user_id',
        ignoreDuplicates: true
      })
    
    const playerUpsertDuration = Date.now() - playerUpsertStart
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=player_upsert_end | duration_ms=${playerUpsertDuration} | error=${playerInsertError ? JSON.stringify(playerInsertError) : 'null'}`)

    if (playerInsertError) {
      console.error('Player insert error:', playerInsertError)
      // Non-fatal
    }

    // console.log(`✅ Player entered lobby: ${match_id}, user: ${user.id}, role: ${isChallenger ? 'challenger' : 'receiver'}`)
    
    const totalDuration = Date.now() - requestStart
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=response_send | total_duration_ms=${totalDuration} | success=true`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Entered lobby successfully',
        data: {
          status: updateData.remote_status || match.remote_status,
          both_players_present: bothPlayersPresent,
          countdown_started: bothPlayersPresent && !match.lobby_countdown_started_at
        }
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    const totalDuration = Date.now() - requestStart
    console.error('Unexpected error:', error)
    console.log(`[TIMING] enter-lobby | matchId=${matchId} | step=error_response | total_duration_ms=${totalDuration} | success=false | error=${JSON.stringify(error)}`)
    return new Response(
      JSON.stringify({ error: 'Internal server error' } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
