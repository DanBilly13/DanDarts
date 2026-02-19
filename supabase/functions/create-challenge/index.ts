// Edge Function: create-challenge
// Creates a new remote match challenge

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders } from '../_shared/cors.ts'
import type { RemoteMatch, ErrorResponse, SuccessResponse } from '../_shared/types.ts'

const CHALLENGE_EXPIRY_SECONDS = 86400 // 24 hours

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get current user
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

    // Parse request body
    const { receiver_id, game_type, match_format } = await req.json()

    // Validate inputs
    if (!receiver_id || !game_type || !match_format) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: receiver_id, game_type, match_format' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate not challenging self
    if (receiver_id === user.id) {
      return new Response(
        JSON.stringify({ error: 'Cannot challenge yourself' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if user already has an active lock
    const { data: existingLock, error: lockCheckError } = await supabaseClient
      .from('remote_match_locks')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle()

    if (lockCheckError) {
      console.error('Lock check error:', lockCheckError)
      return new Response(
        JSON.stringify({ error: 'Database error', details: lockCheckError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (existingLock) {
      return new Response(
        JSON.stringify({ error: 'You already have a match ready. Join or cancel it first.' } as ErrorResponse),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify receiver exists
    const { data: receiver, error: receiverError } = await supabaseClient
      .from('users')
      .select('id')
      .eq('id', receiver_id)
      .maybeSingle()

    if (receiverError || !receiver) {
      return new Response(
        JSON.stringify({ error: 'Receiver not found' } as ErrorResponse),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create challenge
    const now = new Date()
    const expiresAt = new Date(now.getTime() + CHALLENGE_EXPIRY_SECONDS * 1000)

    const matchData = {
      match_mode: 'remote',
      game_type,
      game_name: game_type,
      match_format,
      challenger_id: user.id,
      receiver_id,
      remote_status: 'pending',
      challenge_expires_at: expiresAt.toISOString(),
      created_at: now.toISOString(),
      updated_at: now.toISOString(),
    }

    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .insert(matchData)
      .select()
      .single()

    if (matchError) {
      console.error('Match creation error:', matchError)
      return new Response(
        JSON.stringify({ error: 'Failed to create challenge', details: matchError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Challenge created: ${match.id}`)

    // TODO: Trigger push notification to receiver

    return new Response(
      JSON.stringify({
        success: true,
        data: match,
        message: 'Challenge created successfully',
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
