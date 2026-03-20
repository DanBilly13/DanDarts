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

    // Check if countdown already started (idempotent)
    if (match.lobby_countdown_started_at !== null) {
      console.log('[maybe-start-countdown] Countdown already started - returning success (idempotent)')
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

    // Check both conditions
    const bothVoiceReady = match.challenger_voice_ready_at !== null && match.receiver_voice_ready_at !== null
    const now = new Date()
    const deadline = match.voice_connect_deadline ? new Date(match.voice_connect_deadline) : null
    const deadlinePassed = deadline !== null && now >= deadline

    console.log(`[maybe-start-countdown] bothVoiceReady=${bothVoiceReady}, deadlinePassed=${deadlinePassed}`)

    // If either condition is met, start countdown
    if (bothVoiceReady || deadlinePassed) {
      const reason = bothVoiceReady ? 'voice_ready' : 'timeout'
      
      const { error: updateError } = await supabaseClient
        .from('matches')
        .update({ lobby_countdown_started_at: now.toISOString() })
        .eq('id', match_id)

      if (updateError) {
        console.error('Match update error:', updateError)
        return new Response(
          JSON.stringify({ error: 'Failed to start countdown', details: updateError } as ErrorResponse),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      console.log(`[maybe-start-countdown] ✅ Countdown started (reason: ${reason})`)

      return new Response(
        JSON.stringify({
          success: true,
          countdown_started: true,
          reason: reason,
          message: `Countdown started due to ${reason}`
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Conditions not met yet
    const waitingFor = deadline === null ? 'voice' : 'deadline'
    console.log(`[maybe-start-countdown] Conditions not met yet, waiting for: ${waitingFor}`)

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
