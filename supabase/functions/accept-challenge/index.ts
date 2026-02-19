// Edge Function: accept-challenge
// Accepts a pending challenge and transitions to ready state

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders } from '../_shared/cors.ts'
import type { ErrorResponse, SuccessResponse } from '../_shared/types.ts'

const JOIN_WINDOW_SECONDS = 300 // 5 minutes

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

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

    // Check if user already has an active lock
    const { data: existingLock } = await supabaseClient
      .from('remote_match_locks')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle()

    if (existingLock) {
      return new Response(
        JSON.stringify({ error: 'You already have a match ready. Join or cancel it first.' } as ErrorResponse),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
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

    // Validate user is receiver
    if (match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to accept this challenge' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate status is pending
    if (match.remote_status !== 'pending') {
      return new Response(
        JSON.stringify({ error: 'Challenge is not in pending state' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check not expired
    if (match.challenge_expires_at && new Date(match.challenge_expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Challenge has expired' } as ErrorResponse),
        { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()
    const joinWindowExpiresAt = new Date(now.getTime() + JOIN_WINDOW_SECONDS * 1000)

    // Update match to ready
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'ready',
        join_window_expires_at: joinWindowExpiresAt.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to accept challenge', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create locks for both users
    const locks = [
      {
        user_id: match.challenger_id,
        match_id: match_id,
        lock_status: 'ready',
      },
      {
        user_id: match.receiver_id,
        match_id: match_id,
        lock_status: 'ready',
      },
    ]

    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .insert(locks)

    if (lockError) {
      console.error('Lock creation error:', lockError)
      // Rollback match update
      await supabaseClient
        .from('matches')
        .update({ remote_status: 'pending' })
        .eq('id', match_id)

      return new Response(
        JSON.stringify({ error: 'Failed to create locks', details: lockError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Challenge accepted: ${match_id}`)

    // TODO: Trigger push notification to challenger

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Challenge accepted successfully',
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
