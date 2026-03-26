// Shared countdown evaluator - ONLY place allowed to write lobby_countdown_started_at
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

export interface CountdownEvaluationResult {
  action: 'started' | 'already_started' | 'blocked'
  blockers: string[]
  freshState: {
    remote_status: string
    challenger_joined_at: string | null
    receiver_joined_at: string | null
    challenger_view_entered_at: string | null
    receiver_view_entered_at: string | null
    challenger_voice_ready_at: string | null
    receiver_voice_ready_at: string | null
    lobby_countdown_started_at: string | null
    voice_connect_deadline: string | null
  }
  timestamp: string
}

export async function evaluateAndStartCountdown(
  supabaseClient: ReturnType<typeof createClient>,
  matchId: string,
  trigger: 'immediate_voice_ready' | 'fallback_timeout'
): Promise<CountdownEvaluationResult> {
  const now = new Date()
  const timestamp = now.toISOString()
  const matchIdShort = matchId.substring(0, 8)

  // Log entry
  console.log(`[COUNTDOWN_AUTH] ENTER trigger=${trigger} match=${matchIdShort}`)

  // Fetch fresh authoritative match state
  const { data: freshMatch, error: fetchError } = await supabaseClient
    .from('matches')
    .select('remote_status, challenger_id, challenger_lobby_joined_at, receiver_lobby_joined_at, challenger_lobby_view_entered_at, receiver_lobby_view_entered_at, challenger_voice_ready_at, receiver_voice_ready_at, lobby_countdown_started_at, voice_connect_deadline')
    .eq('id', matchId)
    .single()

  if (fetchError || !freshMatch) {
    console.error(`[COUNTDOWN_AUTH] ERROR match=${matchIdShort} error=${fetchError?.message || 'no match found'}`)
    return {
      action: 'blocked',
      blockers: ['fetch_error'],
      freshState: {
        remote_status: '',
        challenger_joined_at: null,
        receiver_joined_at: null,
        challenger_view_entered_at: null,
        receiver_view_entered_at: null,
        challenger_voice_ready_at: null,
        receiver_voice_ready_at: null,
        lobby_countdown_started_at: null,
        voice_connect_deadline: null
      },
      timestamp
    }
  }

  // Log fresh state
  console.log(`[COUNTDOWN_AUTH] FRESH_STATE remote_status=${freshMatch.remote_status || 'nil'} challenger_joined_at=${freshMatch.challenger_lobby_joined_at || 'nil'} receiver_joined_at=${freshMatch.receiver_lobby_joined_at || 'nil'} challenger_view_entered_at=${freshMatch.challenger_lobby_view_entered_at || 'nil'} receiver_view_entered_at=${freshMatch.receiver_lobby_view_entered_at || 'nil'} challenger_voice_ready_at=${freshMatch.challenger_voice_ready_at || 'nil'} receiver_voice_ready_at=${freshMatch.receiver_voice_ready_at || 'nil'} lobby_countdown_started_at=${freshMatch.lobby_countdown_started_at || 'nil'} voice_connect_deadline=${freshMatch.voice_connect_deadline || 'nil'}`)

  // Compute derived booleans
  const bothJoined = freshMatch.challenger_lobby_joined_at !== null && freshMatch.receiver_lobby_joined_at !== null
  const bothViewed = freshMatch.challenger_lobby_view_entered_at !== null && freshMatch.receiver_lobby_view_entered_at !== null
  const bothVoiceReady = freshMatch.challenger_voice_ready_at !== null && freshMatch.receiver_voice_ready_at !== null
  const alreadyStarted = freshMatch.lobby_countdown_started_at !== null
  const isLobby = freshMatch.remote_status === 'lobby'
  const deadline = freshMatch.voice_connect_deadline ? new Date(freshMatch.voice_connect_deadline) : null
  const deadlinePassed = deadline !== null && now >= deadline

  // Log derived state
  console.log(`[COUNTDOWN_AUTH] DERIVED bothJoined=${bothJoined} bothViewed=${bothViewed} bothVoiceReady=${bothVoiceReady} alreadyStarted=${alreadyStarted} isLobby=${isLobby} deadlinePassed=${deadlinePassed}`)

  // Evaluate core prerequisites (REQUIRED IN BOTH PATHS)
  const blockers: string[] = []
  if (!isLobby) blockers.push('match_not_lobby')
  if (!freshMatch.challenger_lobby_joined_at) blockers.push('challenger_joined_false')
  if (!freshMatch.receiver_lobby_joined_at) blockers.push('receiver_joined_false')
  if (!freshMatch.challenger_lobby_view_entered_at) blockers.push('challenger_view_entered_false')
  if (!freshMatch.receiver_lobby_view_entered_at) blockers.push('receiver_view_entered_false')
  if (alreadyStarted) blockers.push('countdown_already_started')

  // Evaluate voice/deadline gating by trigger
  if (trigger === 'immediate_voice_ready') {
    // Immediate path requires both voice ready
    if (!freshMatch.challenger_voice_ready_at) blockers.push('challenger_voice_ready_false')
    if (!freshMatch.receiver_voice_ready_at) blockers.push('receiver_voice_ready_false')
  } else if (trigger === 'fallback_timeout') {
    // Fallback path requires voice ready OR deadline passed
    // But core prerequisites (status, joined, view_entered) are STILL REQUIRED
    if (!bothVoiceReady && !deadlinePassed) {
      blockers.push('voice_ready_or_deadline_not_met')
    }
  }

  const action = blockers.length === 0 ? 'start_countdown' : 'blocked'
  console.log(`[COUNTDOWN_AUTH] DECISION action=${action} blockers=[${blockers.join(', ')}]`)

  // If blocked, return early
  if (blockers.length > 0) {
    return {
      action: 'blocked',
      blockers,
      freshState: {
        remote_status: freshMatch.remote_status || '',
        challenger_joined_at: freshMatch.challenger_lobby_joined_at,
        receiver_joined_at: freshMatch.receiver_lobby_joined_at,
        challenger_view_entered_at: freshMatch.challenger_lobby_view_entered_at,
        receiver_view_entered_at: freshMatch.receiver_lobby_view_entered_at,
        challenger_voice_ready_at: freshMatch.challenger_voice_ready_at,
        receiver_voice_ready_at: freshMatch.receiver_voice_ready_at,
        lobby_countdown_started_at: freshMatch.lobby_countdown_started_at,
        voice_connect_deadline: freshMatch.voice_connect_deadline
      },
      timestamp
    }
  }

  // Attempt guarded write (countdown + set current_player to challenger to trigger state transition)
  console.log(`[COUNTDOWN_AUTH] WRITE_ATTEMPT guarded=true setting_current_player_id=${freshMatch.challenger_id}`)

  const { data: updateResult, error: updateError } = await supabaseClient
    .from('matches')
    .update({ 
      lobby_countdown_started_at: timestamp,
      current_player_id: freshMatch.challenger_id
    })
    .eq('id', matchId)
    .is('lobby_countdown_started_at', null)
    .select()

  if (updateError) {
    console.error(`[COUNTDOWN_AUTH] WRITE_ERROR match=${matchIdShort} error=${updateError.message}`)
    return {
      action: 'blocked',
      blockers: ['write_error'],
      freshState: {
        remote_status: freshMatch.remote_status || '',
        challenger_joined_at: freshMatch.challenger_lobby_joined_at,
        receiver_joined_at: freshMatch.receiver_lobby_joined_at,
        challenger_view_entered_at: freshMatch.challenger_lobby_view_entered_at,
        receiver_view_entered_at: freshMatch.receiver_lobby_view_entered_at,
        challenger_voice_ready_at: freshMatch.challenger_voice_ready_at,
        receiver_voice_ready_at: freshMatch.receiver_voice_ready_at,
        lobby_countdown_started_at: freshMatch.lobby_countdown_started_at,
        voice_connect_deadline: freshMatch.voice_connect_deadline
      },
      timestamp
    }
  }

  // Check if write succeeded (race safety)
  if (!updateResult || updateResult.length === 0) {
    // Another caller already started countdown
    console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=already_started`)
    return {
      action: 'already_started',
      blockers: [],
      freshState: {
        remote_status: freshMatch.remote_status || '',
        challenger_joined_at: freshMatch.challenger_lobby_joined_at,
        receiver_joined_at: freshMatch.receiver_lobby_joined_at,
        challenger_view_entered_at: freshMatch.challenger_lobby_view_entered_at,
        receiver_view_entered_at: freshMatch.receiver_lobby_view_entered_at,
        challenger_voice_ready_at: freshMatch.challenger_voice_ready_at,
        receiver_voice_ready_at: freshMatch.receiver_voice_ready_at,
        lobby_countdown_started_at: freshMatch.lobby_countdown_started_at,
        voice_connect_deadline: freshMatch.voice_connect_deadline
      },
      timestamp
    }
  }

  // Write succeeded - this caller started countdown
  console.log(`[COUNTDOWN_AUTH] WRITE_RESULT result=started`)
  return {
    action: 'started',
    blockers: [],
    freshState: {
      remote_status: freshMatch.remote_status || '',
      challenger_joined_at: freshMatch.challenger_lobby_joined_at,
      receiver_joined_at: freshMatch.receiver_lobby_joined_at,
      challenger_view_entered_at: freshMatch.challenger_lobby_view_entered_at,
      receiver_view_entered_at: freshMatch.receiver_lobby_view_entered_at,
      challenger_voice_ready_at: freshMatch.challenger_voice_ready_at,
      receiver_voice_ready_at: freshMatch.receiver_voice_ready_at,
      lobby_countdown_started_at: timestamp,
      voice_connect_deadline: freshMatch.voice_connect_deadline
    },
    timestamp
  }
}
