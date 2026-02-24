// Edge Function: create-challenge
// Creates a new remote match challenge

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
  data?: any
}

const CHALLENGE_EXPIRY_SECONDS = 30 // 30 seconds (DEBUG: was 86400/24h)

serve(async (req) => {
  // Handle CORS preflight
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

    // Extract JWT token from Bearer header
    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'Invalid Authorization header' } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        },
      }
    )

    // Get current user using JWT token
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: userError } as ErrorResponse),
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

    // Clean up any locks for expired matches before checking
    const { data: userLocks } = await supabaseClient
      .from('remote_match_locks')
      .select('match_id')
      .eq('user_id', user.id)

    if (userLocks && userLocks.length > 0) {
      // Check each lock's match to see if it's expired
      const lockMatchIds = userLocks.map((lock: any) => lock.match_id)
      
      const { data: lockMatches } = await supabaseClient
        .from('matches')
        .select('id, remote_status, challenge_expires_at, join_window_expires_at')
        .in('id', lockMatchIds)
      
      const now = new Date()
      const expiredMatchIds: string[] = []
      
      lockMatches?.forEach((match: any) => {
        const isExpired = 
          (match.challenge_expires_at && new Date(match.challenge_expires_at) < now) ||
          (match.join_window_expires_at && new Date(match.join_window_expires_at) < now) ||
          match.remote_status === 'expired' ||
          match.remote_status === 'cancelled' ||
          match.remote_status === 'completed'
        
        if (isExpired) {
          expiredMatchIds.push(match.id)
        }
      })
      
      // Delete locks for expired/finished matches
      if (expiredMatchIds.length > 0) {
        await supabaseClient
          .from('remote_match_locks')
          .delete()
          .in('match_id', expiredMatchIds)
        
        console.log(`🧹 Cleaned up ${expiredMatchIds.length} expired locks for user ${user.id}`)
      }
    }

    // Now check if user has any remaining active locks
    // Only block on ACTIVE statuses (not terminal ones)
    const { data: existingLock, error: lockCheckError } = await supabaseClient
      .from('remote_match_locks')
      .select('match_id')
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
      // Verify the match is actually in an active state
      const { data: lockMatch } = await supabaseClient
        .from('matches')
        .select('remote_status')
        .eq('id', existingLock.match_id)
        .maybeSingle()
      
      // Only block if match is in active state
      const activeStatuses = ['pending', 'ready', 'lobby', 'in_progress']
      if (lockMatch && activeStatuses.includes(lockMatch.remote_status)) {
        return new Response(
          JSON.stringify({ 
            error: 'You already have an active match. Cancel/Abort or wait for it to expire.',
            match_id: existingLock.match_id
          } as ErrorResponse),
          { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      } else {
        // Lock exists but match is terminal - clean up the stale lock
        await supabaseClient
          .from('remote_match_locks')
          .delete()
          .eq('match_id', existingLock.match_id)
        
        console.log(`🧹 Cleaned up stale lock for terminal match ${existingLock.match_id}`)
      }
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
