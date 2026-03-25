import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CountdownRequest {
  match_id: string
}

interface SuccessResponse {
  success: true
  countdown_started: boolean
  already_started?: boolean
  reason?: 'voice_ready' | 'timeout' | 'already_started'
  waiting_for?: 'voice' | 'deadline'
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

    const { match_id } = await req.json() as CountdownRequest

    console.log(`[maybe-start-countdown] User ${user.id} checking countdown for match ${match_id}`)

    // Fetch match with all authoritative fields
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('remote_status, current_player_id, lobby_countdown_started_at, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_lobby_view_entered_at, receiver_lobby_view_entered_at, challenger_voice_ready_at, receiver_voice_ready_at, voice_connect_deadline')
      .eq('id', match_id)
      .single()

    if (matchError || !match) {
      console.error('Match fetch error:', matchError)
      return new Response(
        JSON.stringify({ error: 'Match not found', details: matchError } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // COUNTDOWN EVALUATOR (INLINED) - ONLY place allowed to write lobby_countdown_started_at
    const now = new Date()
    const matchIdShort = match_id.substring(0, 8)
    console.log(`[COUNTDOWN_AUTH] ENTER trigger=fallback_timeout match=${matchIdShort}`)

    // Fetch fresh authoritative match state
    const { data: freshMatch, error: fetchError } = await supabaseClient
      .from('matches')
      .select('remote_status, challenger_id, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_lobby_view_entered_at, receiver_lobby_view_entered_at, challenger_voice_ready_at, receiver_voice_ready_at, lobby_countdown_started_at, voice_connect_deadline')
      .eq('id', match_id)
      .single()

    if (fetchError || !freshMatch) {
      console.error(`[COUNTDOWN_AUTH] ERROR match=${matchIdShort} error=${fetchError?.message || 'no match found'}`)
      return new Response(
        JSON.stringify({ error: 'Match not found', details: fetchError } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[COUNTDOWN_AUTH] FRESH_STATE remote_status=${freshMatch.remote_status || 'nil'} challenger_joined=${freshMatch.challenger_lobby_joined_at || 'nil'} receiver_joined=${freshMatch.receiver_lobby_joined_at || 'nil'} challenger_view=${freshMatch.challenger_lobby_view_entered_at || 'nil'} receiver_view=${freshMatch.receiver_lobby_view_entered_at || 'nil'} challenger_voice=${freshMatch.challenger_voice_ready_at || 'nil'} receiver_voice=${freshMatch.receiver_voice_ready_at || 'nil'} countdown_started=${freshMatch.lobby_countdown_started_at || 'nil'} deadline=${freshMatch.voice_connect_deadline || 'nil'}`)

    // Evaluate core prerequisites
    const isLobby = freshMatch.remote_status === 'lobby'
    const bothJoined = freshMatch.challenger_lobby_joined_at !== null && freshMatch.receiver_lobby_joined_at !== null
    const bothViewed = freshMatch.challenger_lobby_view_entered_at !== null && freshMatch.receiver_lobby_view_entered_at !== null
    const bothVoiceReady = freshMatch.challenger_voice_ready_at !== null && freshMatch.receiver_voice_ready_at !== null
    const alreadyStarted = freshMatch.lobby_countdown_started_at !== null
    const deadline = freshMatch.voice_connect_deadline ? new Date(freshMatch.voice_connect_deadline) : null
    const deadlinePassed = deadline !== null && now >= deadline

    console.log(`[COUNTDOWN_AUTH] DERIVED isLobby=${isLobby} bothJoined=${bothJoined} bothViewed=${bothViewed} bothVoiceReady=${bothVoiceReady} alreadyStarted=${alreadyStarted} deadlinePassed=${deadlinePassed}`)

    // Check if already started
    if (alreadyStarted) {
      console.log(`[COUNTDOWN_AUTH] DECISION action=already_started`)
      return new Response(
        JSON.stringify({
          success: true,
          countdown_started: true,
          already_started: true,
          reason: 'already_started',
          message: 'Countdown already started'
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check blockers
    const blockers: string[] = []
    if (!isLobby) blockers.push('match_not_lobby')
    if (!bothJoined) blockers.push('both_joined_false')
    if (!bothViewed) blockers.push('both_viewed_false')
    // Fallback path: requires voice ready OR deadline passed
    if (!bothVoiceReady && !deadlinePassed) {
      blockers.push('voice_ready_or_deadline_not_met')
    }

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
        return new Response(
          JSON.stringify({ error: 'Failed to start countdown', details: updateError } as ErrorResponse),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      if (!updateResult || updateResult.length === 0) {
        console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=already_started (race condition)`)
        return new Response(
          JSON.stringify({
            success: true,
            countdown_started: true,
            already_started: true,
            reason: 'already_started',
            message: 'Countdown already started'
          } as SuccessResponse),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=started ✅`)
      const reason = bothVoiceReady ? 'voice_ready' : 'timeout'
      return new Response(
        JSON.stringify({
          success: true,
          countdown_started: true,
          reason: reason,
          message: `Countdown started due to ${bothVoiceReady ? 'both players voice ready' : 'voice deadline timeout'}`
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Blocked - conditions not met yet
    const waitingFor = deadline === null ? 'voice' : 'deadline'
    return new Response(
      JSON.stringify({
        success: true,
        countdown_started: false,
        waiting_for: waitingFor,
        message: `Waiting for ${waitingFor}`
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
