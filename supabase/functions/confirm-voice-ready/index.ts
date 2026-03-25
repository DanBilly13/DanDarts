import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VoiceReadyRequest {
  match_id: string
}

interface SuccessResponse {
  success: true
  voice_ready_recorded: boolean
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

    const { match_id } = await req.json() as VoiceReadyRequest

    console.log(`[confirm-voice-ready] User ${user.id} confirming voice ready for match ${match_id}`)

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
    const voiceReadyField = isChallenger ? 'challenger_voice_ready_at' : 'receiver_voice_ready_at'

    const now = new Date()
    
    // IDEMPOTENT: Check if already set
    const alreadyVoiceReady = match[voiceReadyField] !== null

    if (alreadyVoiceReady) {
      console.log(`[confirm-voice-ready] ${role} voice already confirmed - skipping write, continuing countdown evaluation`)
    } else {
      const updateData: any = {}
      updateData[voiceReadyField] = now.toISOString()
      console.log(`[confirm-voice-ready] Setting ${voiceReadyField} for ${role}`)

      // Update match
      const { error: updateError } = await supabaseClient
        .from('matches')
        .update(updateData)
        .eq('id', match_id)

      if (updateError) {
        console.error('Match update error:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to confirm voice ready', details: updateError } as ErrorResponse),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log(`[confirm-voice-ready] ✅ Voice ready recorded for ${role}`)
    }

    // COUNTDOWN EVALUATOR (INLINED) - ONLY place allowed to write lobby_countdown_started_at
    const matchIdShort = match_id.substring(0, 8)
    console.log(`[COUNTDOWN_AUTH] ENTER trigger=immediate_voice_ready match=${matchIdShort}`)

    // Fetch fresh authoritative match state
    const { data: freshMatch, error: fetchError } = await supabaseClient
      .from('matches')
      .select('remote_status, challenger_id, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_lobby_view_entered_at, receiver_lobby_view_entered_at, challenger_voice_ready_at, receiver_voice_ready_at, lobby_countdown_started_at')
      .eq('id', match_id)
      .single()

    if (fetchError || !freshMatch) {
      console.error(`[COUNTDOWN_AUTH] ERROR match=${matchIdShort} error=${fetchError?.message || 'no match found'}`)
    } else {
      console.log(`[COUNTDOWN_AUTH] FRESH_STATE remote_status=${freshMatch.remote_status || 'nil'} challenger_joined=${freshMatch.challenger_lobby_joined_at || 'nil'} receiver_joined=${freshMatch.receiver_lobby_joined_at || 'nil'} challenger_view=${freshMatch.challenger_lobby_view_entered_at || 'nil'} receiver_view=${freshMatch.receiver_lobby_view_entered_at || 'nil'} challenger_voice=${freshMatch.challenger_voice_ready_at || 'nil'} receiver_voice=${freshMatch.receiver_voice_ready_at || 'nil'} countdown_started=${freshMatch.lobby_countdown_started_at || 'nil'}`)

      // Evaluate core prerequisites
      const isLobby = freshMatch.remote_status === 'lobby'
      const bothJoined = freshMatch.challenger_lobby_joined_at !== null && freshMatch.receiver_lobby_joined_at !== null
      const bothViewed = freshMatch.challenger_lobby_view_entered_at !== null && freshMatch.receiver_lobby_view_entered_at !== null
      const bothVoiceReady = freshMatch.challenger_voice_ready_at !== null && freshMatch.receiver_voice_ready_at !== null
      const alreadyStarted = freshMatch.lobby_countdown_started_at !== null

      console.log(`[COUNTDOWN_AUTH] DERIVED isLobby=${isLobby} bothJoined=${bothJoined} bothViewed=${bothViewed} bothVoiceReady=${bothVoiceReady} alreadyStarted=${alreadyStarted}`)

      // Check blockers
      const blockers: string[] = []
      if (!isLobby) blockers.push('match_not_lobby')
      if (!bothJoined) blockers.push('both_joined_false')
      if (!bothViewed) blockers.push('both_viewed_false')
      if (!bothVoiceReady) blockers.push('both_voice_ready_false')
      if (alreadyStarted) blockers.push('countdown_already_started')

      const action = blockers.length === 0 ? 'start_countdown' : 'blocked'
      console.log(`[COUNTDOWN_AUTH] DECISION action=${action} blockers=[${blockers.join(', ')}]`)

      // Attempt guarded write if not blocked
      if (blockers.length === 0) {
        console.log(`[COUNTDOWN_AUTH] WRITE_ATTEMPT guarded=true setting_current_player_id=${freshMatch.challenger_id}`)

        const { data: updateResult, error: updateError } = await supabaseClient
          .from('matches')
          .update({ 
            lobby_countdown_started_at: now.toISOString(),
            current_player_id: freshMatch.challenger_id
          })
          .eq('id', match_id)
          .is('lobby_countdown_started_at', null)
          .select()

        if (updateError) {
          console.error(`[COUNTDOWN_AUTH] WRITE_ERROR match=${matchIdShort} error=${updateError.message}`)
        } else if (!updateResult || updateResult.length === 0) {
          console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=already_started (race condition)`)
        } else {
          console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=started ✅`)
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        voice_ready_recorded: true,
        message: `Voice ready confirmed for ${role}`
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
