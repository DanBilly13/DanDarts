// Edge Function: join-match
// Joins a ready match and transitions to in_progress

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

    const jwt = authHeader.replace('Bearer ', '').trim()

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: `Bearer ${jwt}` }
        },
      }
    )

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
        JSON.stringify({ error: 'Not authorized to join this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate status is ready or lobby
    if (match.remote_status !== 'ready' && match.remote_status !== 'lobby') {
      return new Response(
        JSON.stringify({ error: `Match is not joinable (status: ${match.remote_status})` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check not expired
    if (match.join_window_expires_at && new Date(match.join_window_expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Join window has expired' } as ErrorResponse),
        { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()

    // Determine new status based on current status
    // ready → lobby (first player joins)
    // lobby → in_progress (second player joins)
    let newStatus: string
    let currentPlayerId = null

    if (match.remote_status === 'ready') {
      // First player joining - transition to lobby
      newStatus = 'lobby'
      console.log('First player joining - transitioning to lobby')
    } else if (match.remote_status === 'lobby') {
      // Second player joining - transition to in_progress
      newStatus = 'in_progress'
      currentPlayerId = match.challenger_id // Challenger goes first
      console.log('Second player joining - transitioning to in_progress')
    } else {
      // Invalid state
      return new Response(
        JSON.stringify({ error: `Cannot join match in ${match.remote_status} state` } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update match status
    const updateData: any = {
      remote_status: newStatus,
      updated_at: now.toISOString(),
    }

    if (currentPlayerId) {
      updateData.current_player_id = currentPlayerId
    }

    const { error: updateError } = await supabaseClient
      .from('matches')
      .update(updateData)
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to join match', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create match_player record for this user if not exists
    const playerOrder = user.id === match.challenger_id ? 0 : 1
    const { error: playerInsertError } = await supabaseClient
      .from('match_players')
      .upsert({
        match_id: match_id,
        player_user_id: user.id,
        player_order: playerOrder,
      }, {
        onConflict: 'match_id,player_user_id',
        ignoreDuplicates: true
      })

    if (playerInsertError) {
      console.error('Player insert error:', playerInsertError)
      // Non-fatal
    }

    // Update locks if transitioning to in_progress
    if (newStatus === 'in_progress') {
      const { error: lockError } = await supabaseClient
        .from('remote_match_locks')
        .update({ lock_status: 'in_progress' })
        .eq('match_id', match_id)

      if (lockError) {
        console.error('Lock update error:', lockError)
        // Non-fatal - match is already in_progress
      }
    }

    console.log(`✅ Match joined: ${match_id}, status: ${newStatus}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: { 
          status: newStatus,
          current_player_id: currentPlayerId 
        },
        message: 'Match joined successfully',
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
