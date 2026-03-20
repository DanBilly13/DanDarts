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

    // IDEMPOTENT: Check if already set
    if (match[voiceReadyField] !== null) {
      console.log(`[confirm-voice-ready] ${role} voice already confirmed - returning success (idempotent)`)
      return new Response(
        JSON.stringify({
          success: true,
          voice_ready_recorded: true,
          message: 'Voice ready already confirmed (idempotent)'
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()
    const updateData: any = {}

    // Set this player's voice-ready timestamp
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

    console.log(`[confirm-voice-ready] ✅ Success for ${role}`)

    // Check if both players are now voice ready and trigger countdown if so
    const { data: updatedMatch } = await supabaseClient
      .from('matches')
      .select('challenger_voice_ready_at, receiver_voice_ready_at')
      .eq('id', match_id)
      .single()

    if (updatedMatch?.challenger_voice_ready_at && updatedMatch?.receiver_voice_ready_at) {
      console.log('[confirm-voice-ready] Both players voice ready - triggering countdown check')
      
      // Call maybe-start-countdown
      try {
        const countdownUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/maybe-start-countdown`
        const countdownResponse = await fetch(countdownUrl, {
          method: 'POST',
          headers: {
            'Authorization': req.headers.get('Authorization')!,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ match_id })
        })
        
        if (!countdownResponse.ok) {
          console.error('[confirm-voice-ready] Failed to trigger countdown check:', await countdownResponse.text())
        } else {
          console.log('[confirm-voice-ready] ✅ Countdown check triggered successfully')
        }
      } catch (countdownError) {
        console.error('[confirm-voice-ready] Error calling maybe-start-countdown:', countdownError)
        // Don't fail the voice-ready confirmation if countdown trigger fails
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
