// Edge Function: accept-challenge (WITH DEBUGGING + FIXED AUTH + SENT STATE)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ErrorResponse {
  error: string
  details?: any
  debug?: any
}

interface SuccessResponse {
  success: boolean
  message: string
  data?: any
  debug?: any
}

const JOIN_WINDOW_SECONDS = 300

serve(async (req) => {
  console.log('🔍 accept-challenge invoked')
  console.log('📋 Request method:', req.method)
  console.log('📋 Request URL:', req.url)
  
  // Log all headers (safely)
  const headerEntries = Array.from(req.headers.entries())
  console.log('📋 All headers:', headerEntries.map(([k, v]) => 
    k.toLowerCase().includes('auth') || k.toLowerCase().includes('key') 
      ? `${k}: ${v.substring(0, 20)}...` 
      : `${k}: ${v}`
  ))
  
  if (req.method === 'OPTIONS') {
    console.log('✅ CORS preflight - returning ok')
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    const apikeyHeader = req.headers.get('apikey')
    
    console.log('🔑 Authorization header:', authHeader ? `${authHeader.substring(0, 30)}...` : '❌ MISSING')
    console.log('🔑 apikey header:', apikeyHeader ? `${apikeyHeader.substring(0, 20)}...` : '❌ MISSING')
    
    if (!authHeader) {
      console.error('❌ CRITICAL: No Authorization header')
      return new Response(JSON.stringify({ 
        error: 'Missing Authorization header',
        debug: 'Authorization header is required but was not provided'
      } as ErrorResponse), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    if (!apikeyHeader) {
      console.error('❌ CRITICAL: No apikey header')
      return new Response(JSON.stringify({ 
        error: 'Missing apikey header',
        debug: 'apikey header is required but was not provided'
      } as ErrorResponse), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    // ✅ Extract JWT and use getUser(jwt) — avoids AuthSessionMissingError in Edge runtime
    const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null
    if (!jwt) {
      console.error('❌ CRITICAL: Authorization header missing Bearer token')
      return new Response(
        JSON.stringify({
          error: 'Invalid Authorization header',
          debug: 'Expected Authorization: Bearer <token>',
        } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('🔧 Creating Supabase client...')
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: { headers: { Authorization: authHeader } },
      }
    )
    console.log('✅ Supabase client created')

    console.log('🔍 Attempting to get user...')
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt)
    
    if (userError) {
      console.error('❌ User authentication error:', userError)
      return new Response(JSON.stringify({ 
        error: 'Unauthorized', 
        details: userError,
        debug: 'Failed to authenticate user with provided token'
      } as ErrorResponse), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    if (!user) {
      console.error('❌ No user found (token may be invalid or expired)')
      return new Response(JSON.stringify({ 
        error: 'Unauthorized - no user',
        debug: 'Token was accepted but no user was returned'
      } as ErrorResponse), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    console.log('✅ User authenticated:', user.id)
    console.log('   - Email:', user.email)

    console.log('📝 Parsing request body...')
    const { match_id } = await req.json()
    console.log('📝 Match ID:', match_id)
    
    if (!match_id) {
      console.error('❌ Missing match_id in request body')
      return new Response(JSON.stringify({ error: 'Missing required field: match_id' } as ErrorResponse), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log('🔍 Checking for existing lock...')
    const { data: existingLock } = await supabaseClient
      .from('remote_match_locks')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle()

    if (existingLock) {
      console.log('⚠️ User already has an active lock:', existingLock)
      return new Response(JSON.stringify({ error: 'You already have a match ready. Join or cancel it first.' } as ErrorResponse), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    console.log('✅ No existing lock')

    console.log('🔍 Fetching match...')
    const { data: match, error: matchError } = await supabaseClient
      .from('matches')
      .select('*')
      .eq('id', match_id)
      .maybeSingle()

    if (matchError) {
      console.error('❌ Error fetching match:', matchError)
      return new Response(JSON.stringify({ error: 'Database error', details: matchError } as ErrorResponse), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!match) {
      console.error('❌ Match not found:', match_id)
      return new Response(JSON.stringify({ error: 'Match not found' } as ErrorResponse), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    console.log('✅ Match found:', match.id)
    console.log('   - Status:', match.remote_status)
    console.log('   - Challenger:', match.challenger_id)
    console.log('   - Receiver:', match.receiver_id)

    if (match.receiver_id !== user.id) {
      console.error('❌ User is not the receiver. User:', user.id, 'Receiver:', match.receiver_id)
      return new Response(JSON.stringify({ error: 'Not authorized to accept this challenge' } as ErrorResponse), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    console.log('✅ User is the receiver')

    // ✅ New state is `sent`. Allow legacy `pending` temporarily if you still have old records.
    if (match.remote_status !== 'sent' && match.remote_status !== 'pending') {
      console.error('❌ Match status is not sent/pending:', match.remote_status)
      return new Response(
        JSON.stringify({
          error: 'Challenge is not in sent state',
          debug: `Current status: ${match.remote_status}`,
        } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    console.log('✅ Match status is valid for accept (sent/pending)')

    if (match.challenge_expires_at && new Date(match.challenge_expires_at) < new Date()) {
      console.error('❌ Challenge has expired:', match.challenge_expires_at)
      return new Response(JSON.stringify({ error: 'Challenge has expired' } as ErrorResponse), {
        status: 410,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    console.log('✅ Challenge not expired')

    const now = new Date()
    const joinWindowExpiresAt = new Date(now.getTime() + JOIN_WINDOW_SECONDS * 1000)

    console.log('🔄 Updating match to ready...')
    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'ready',
        join_window_expires_at: joinWindowExpiresAt.toISOString(),
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)

    if (updateError) {
      console.error('❌ Failed to update match:', updateError)
      return new Response(JSON.stringify({ error: 'Failed to accept challenge', details: updateError } as ErrorResponse), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    console.log('✅ Match updated to ready')

    console.log('🔒 Creating locks...')
    const locks = [
      { user_id: match.challenger_id, match_id, lock_status: 'ready' },
      { user_id: match.receiver_id, match_id, lock_status: 'ready' },
    ]

    const { error: lockError } = await supabaseClient.from('remote_match_locks').insert(locks)

    if (lockError) {
      console.error('❌ Failed to create locks:', lockError)
      console.log('🔄 Rolling back match status to sent...')
      await supabaseClient.from('matches').update({ remote_status: 'sent' }).eq('id', match_id)

      return new Response(JSON.stringify({ error: 'Failed to create locks', details: lockError } as ErrorResponse), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    console.log('✅ Locks created')

    console.log('🎉 Challenge accepted successfully!')
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Challenge accepted successfully',
      debug: {
        match_id,
        user_id: user.id,
        join_window_expires_at: joinWindowExpiresAt.toISOString()
      }
    } as SuccessResponse), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('❌ Unexpected error:', error)
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      details: error.message,
      stack: error.stack
    } as ErrorResponse), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
