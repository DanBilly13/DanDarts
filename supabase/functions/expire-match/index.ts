// Edge Function: expire-match
// Client-triggered expiration for immediate responsiveness
// Idempotent and safe to call multiple times

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

    // CRITICAL: Extract JWT token from Bearer header
    // This pattern is required to avoid AuthSessionMissingError
    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'Invalid Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        },
      }
    )

    // CRITICAL: Pass JWT as parameter to getUser()
    // Simply passing Authorization header to client is NOT sufficient
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' } as ErrorResponse),
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
        JSON.stringify({ error: 'Not authorized to expire this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Idempotent: if already terminal, return success
    if (['expired', 'cancelled', 'completed'].includes(match.remote_status)) {
      console.log(`✅ Match ${match_id} already terminal (${match.remote_status})`)
      return new Response(
        JSON.stringify({
          success: true,
          message: `Match already ${match.remote_status}`,
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()

    // Update match to expired (only if in active state)
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'expired',
        ended_at: now.toISOString(),
        ended_reason: 'expired',
        ended_by: null,
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)
      .in('remote_status', ['pending', 'ready', 'lobby', 'in_progress'])

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to expire match', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Clear locks
    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .delete()
      .eq('match_id', match_id)

    if (lockError) {
      console.error('Lock deletion error:', lockError)
      // Non-fatal - match is already expired
    }

    console.log(`✅ Match expired: ${match_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Match expired successfully',
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
