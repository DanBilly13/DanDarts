import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ConfirmRequest {
  match_id: string
}

interface SuccessResponse {
  success: true
  voice_window_started: boolean
  countdown_started: boolean
  message: string
}

interface ErrorResponse {
  error: string
  details?: any
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const t0 = performance.now()
  console.log(`⏱️ [enter-lobby] START`)

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const t1 = performance.now()
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    const t2 = performance.now()
    console.log(`⏱️ [enter-lobby] AUTH: ${(t2-t1).toFixed(0)}ms`)
    
    if (userError || !user) {
      console.error('Auth error:', userError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id } = await req.json() as ConfirmRequest

    console.log(`[confirm-lobby-view-entered] User ${user.id} confirming for match ${match_id}`)

    // Fetch match with all authoritative fields
    const t3 = performance.now()
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('remote_status, current_player_id, lobby_countdown_started_at, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_voice_ready_at, receiver_voice_ready_at, voice_connect_window_started_at, voice_connect_deadline, challenger_lobby_view_entered_at, receiver_lobby_view_entered_at, challenger_id, receiver_id')
      .eq('id', match_id)
      .single()
    const t4 = performance.now()
    console.log(`⏱️ [enter-lobby] FETCH: ${(t4-t3).toFixed(0)}ms`)

    if (matchError || !match) {
      console.error('Match fetch error:', matchError)
      return new Response(
        JSON.stringify({ error: 'Match not found', details: matchError } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Determine role
    const isChallenger = user.id === match.challenger_id
    const isReceiver = user.id === match.receiver_id

    if (!isChallenger && !isReceiver) {
      console.error('User is not a participant')
      return new Response(
        JSON.stringify({ error: 'Not a participant in this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const role = isChallenger ? 'challenger' : 'receiver'
    const viewEnteredField = isChallenger ? 'challenger_lobby_view_entered_at' : 'receiver_lobby_view_entered_at'
    const otherViewEnteredField = isChallenger ? 'receiver_lobby_view_entered_at' : 'challenger_lobby_view_entered_at'
    
    const matchIdShort = match_id.substring(0, 8)
    const timestamp = new Date().toISOString()

    // IDEMPOTENT: Check if already set
    if (match[viewEnteredField] !== null) {
      console.log(`[confirm-lobby-view-entered] ${role} already confirmed - returning success (idempotent)`)
      return new Response(
        JSON.stringify({
          success: true,
          voice_window_started: match.voice_connect_window_started_at !== null,
          countdown_started: match.lobby_countdown_started_at !== null,
          message: 'Already confirmed (idempotent)'
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()
    const updateData: any = {}

    // Set this player's view-entered timestamp
    updateData[viewEnteredField] = now.toISOString()
    console.log(`[confirm-lobby-view-entered] Setting ${viewEnteredField} for ${role}`)

    // Check if both players have now entered lobby view
    // Use authoritative combination: existing DB value + current update
    const otherPlayerEntered = match[otherViewEnteredField] !== null
    const bothViewsEntered = otherPlayerEntered // Current player is entering now

    console.log(`[confirm-lobby-view-entered] Both views entered: ${bothViewsEntered} (other=${otherPlayerEntered})`)

    // Start voice connection window ONLY if:
    // 1. Both views entered
    // 2. Voice window not already started (idempotent guard)
    let voiceWindowStarted = false
    if (bothViewsEntered && match.voice_connect_window_started_at === null) {
      const voiceDeadline = new Date(now.getTime() + 20000) // 20 seconds from now
      updateData.voice_connect_window_started_at = now.toISOString()
      updateData.voice_connect_deadline = voiceDeadline.toISOString()
      voiceWindowStarted = true
      console.log('[confirm-lobby-view-entered] ✅ Both players in lobby UI - STARTING VOICE CONNECTION WINDOW (20s)')
    } else if (match.voice_connect_window_started_at !== null) {
      console.log('[confirm-lobby-view-entered] Voice window already started - skipping (idempotent)')
    } else {
      console.log('[confirm-lobby-view-entered] Waiting for other player to enter lobby UI')
    }

    // Log old values before update
    const oldValue = match[viewEnteredField]
    console.log(`[LOBBY_STATE] PRE-UPDATE match=${matchIdShort} ${viewEnteredField}: ${oldValue || 'nil'} → ${updateData[viewEnteredField]}`)
    
    // Update match
    const t5 = performance.now()
    const { data: updateResult, error: updateError, count } = await supabaseClient
      .from('matches')
      .update(updateData)
      .eq('id', match_id)
      .select()
    const t6 = performance.now()
    console.log(`⏱️ [enter-lobby] UPDATE: ${(t6-t5).toFixed(0)}ms`)

    if (updateError) {
      console.error('Match update error:', updateError)
      console.log(`[COUNTDOWN_AUTH] LOBBY_VIEW_ENTER_ERROR match=${matchIdShort} error=${updateError.message}`)
      return new Response(
        JSON.stringify({ error: 'Failed to confirm lobby view entered', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Validate that update actually affected a row
    if (!updateResult || updateResult.length === 0) {
      console.error('[confirm-lobby-view-entered] Update succeeded but affected 0 rows - state not persisted!')
      console.log(`[COUNTDOWN_AUTH] LOBBY_VIEW_ENTER_ERROR match=${matchIdShort} error="zero rows affected"`)
      return new Response(
        JSON.stringify({ error: 'Failed to persist lobby view entered state', details: 'No rows affected' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Log new values after update to prove state changed
    const updatedMatch = updateResult[0]
    const newValue = updatedMatch[viewEnteredField]
    console.log(`[LOBBY_STATE] POST-UPDATE match=${matchIdShort} ${viewEnteredField}: ${oldValue || 'nil'} → ${newValue || 'nil'} (PERSISTED)`)
    console.log(`[LOBBY_STATE] POST-UPDATE match=${matchIdShort} voice_window_started_at: ${match.voice_connect_window_started_at || 'nil'} → ${updatedMatch.voice_connect_window_started_at || 'nil'}`)
    
    // Validate that the value actually changed (not a no-op)
    if (oldValue === null && newValue === null) {
      console.error('[confirm-lobby-view-entered] Update succeeded but value unchanged (nil → nil) - fake success!')
      console.log(`[COUNTDOWN_AUTH] LOBBY_VIEW_ENTER_ERROR match=${matchIdShort} error="value unchanged"`)
      return new Response(
        JSON.stringify({ error: 'Failed to change lobby view entered state', details: 'Value remained null' } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[confirm-lobby-view-entered] ✅ Success for ${role}, voice_window_started=${voiceWindowStarted}`)
    
    // Event H: LOBBY_VIEW_ENTER_CONFIRM - authoritative lobby view entered persisted
    console.log(`[COUNTDOWN_AUTH] LOBBY_VIEW_ENTER_CONFIRM match=${matchIdShort} timestamp=${timestamp} evaluator_function=confirm_lobby_view_entered`)
    console.log(`[COUNTDOWN_AUTH]   side=${role} challenger_joined=${match.challenger_lobby_joined_at !== null} receiver_joined=${match.receiver_lobby_joined_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   challenger_voice_ready=${match.challenger_voice_ready_at !== null} receiver_voice_ready=${match.receiver_voice_ready_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   challenger_view_entered=${isChallenger || match.challenger_lobby_view_entered_at !== null} receiver_view_entered=${!isChallenger || match.receiver_lobby_view_entered_at !== null}`)
    console.log(`[COUNTDOWN_AUTH]   countdown_started_at=${match.lobby_countdown_started_at || 'nil'} match_status=${match.remote_status} voice_window_started=${voiceWindowStarted}`)

    const t7 = performance.now()
    console.log(`⏱️ [enter-lobby] TOTAL: ${(t7-t0).toFixed(0)}ms`)

    return new Response(
      JSON.stringify({
        success: true,
        voice_window_started: voiceWindowStarted,
        countdown_started: false, // Countdown no longer starts here
        message: `Lobby view entered confirmed for ${role}`
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
