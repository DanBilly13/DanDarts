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

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      console.error('Auth error:', userError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { match_id } = await req.json() as ConfirmRequest

    console.log(`[confirm-lobby-view-entered] User ${user.id} confirming for match ${match_id}`)

    // Fetch match
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', match_id)
      .single()

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

    // IDEMPOTENT: Check if already set
    if (match[viewEnteredField] !== null) {
      console.log(`[confirm-lobby-view-entered] ${role} already confirmed - returning success (idempotent)`)
      return new Response(
        JSON.stringify({
          success: true,
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

    // Start countdown ONLY if:
    // 1. Both views entered
    // 2. Countdown not already started (idempotent guard)
    let countdownStarted = false
    if (bothViewsEntered && match.lobby_countdown_started_at === null) {
      updateData.lobby_countdown_started_at = now.toISOString()
      countdownStarted = true
      console.log('[confirm-lobby-view-entered] ✅ Both players in lobby UI - STARTING COUNTDOWN')
    } else if (match.lobby_countdown_started_at !== null) {
      console.log('[confirm-lobby-view-entered] Countdown already started - skipping (idempotent)')
    } else {
      console.log('[confirm-lobby-view-entered] Waiting for other player to enter lobby UI')
    }

    // Update match
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update(updateData)
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to confirm lobby view entered', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[confirm-lobby-view-entered] ✅ Success for ${role}, countdown_started=${countdownStarted}`)

    return new Response(
      JSON.stringify({
        success: true,
        countdown_started: countdownStarted,
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
