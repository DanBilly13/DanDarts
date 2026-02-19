// Edge Function: save-visit
// Saves a visit (3 darts) for a remote match with server-side validation

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders } from '../_shared/cors.ts'
import type { ErrorResponse, SuccessResponse } from '../_shared/types.ts'

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

    const { match_id, darts, score_before, score_after } = await req.json()

    if (!match_id || !darts || score_before === undefined || score_after === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate darts array
    if (!Array.isArray(darts) || darts.length !== 3) {
      return new Response(
        JSON.stringify({ error: 'Darts must be an array of 3 scores' } as ErrorResponse),
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

    // Validate user is participant
    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized for this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate status is in_progress
    if (match.remote_status !== 'in_progress') {
      return new Response(
        JSON.stringify({ error: 'Match is not in progress' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate it's user's turn
    if (match.current_player_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not your turn' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()

    // Determine next player
    const nextPlayerId = match.current_player_id === match.challenger_id 
      ? match.receiver_id 
      : match.challenger_id

    // Store visit payload for 1-2s reveal animation
    const visitPayload = {
      player_id: user.id,
      darts,
      score_before,
      score_after,
      timestamp: now.toISOString(),
    }

    // Update match with next player and last visit
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        current_player_id: nextPlayerId,
        last_visit_payload: visitPayload,
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to save visit', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // TODO: Save to match_throws table for history

    console.log(`✅ Visit saved for match: ${match_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: { next_player_id: nextPlayerId },
        message: 'Visit saved successfully',
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
