# Edge Functions Deployment Guide

Copy and paste these functions into the Supabase Dashboard via "Deploy a new function" → "Via Editor"

---

## 1. accept-challenge

**Function Name:** `accept-challenge`

**Code:**
```typescript
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

const JOIN_WINDOW_SECONDS = 300

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

    if (match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to accept this challenge' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (match.remote_status !== 'pending') {
      return new Response(
        JSON.stringify({ error: 'Challenge is not in pending state' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (match.challenge_expires_at && new Date(match.challenge_expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Challenge has expired' } as ErrorResponse),
        { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()
    const joinWindowExpiresAt = new Date(now.getTime() + JOIN_WINDOW_SECONDS * 1000)

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
```

---

## 2. create-challenge

**Function Name:** `create-challenge`

**Code:**
```typescript
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

const CHALLENGE_EXPIRY_SECONDS = 86400

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

    const { receiver_id, game_type, match_format } = await req.json()

    if (!receiver_id || !game_type || !match_format) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: receiver_id, game_type, match_format' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (receiver_id === user.id) {
      return new Response(
        JSON.stringify({ error: 'Cannot challenge yourself' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

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
```

---

## 3. cancel-match

**Function Name:** `cancel-match`

**Code:**
```typescript
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

    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to cancel this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (match.remote_status !== 'pending' && match.remote_status !== 'ready') {
      return new Response(
        JSON.stringify({ error: 'Can only cancel pending or ready matches' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()

    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'cancelled',
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to cancel match', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .delete()
      .eq('match_id', match_id)

    if (lockError) {
      console.error('Lock deletion error:', lockError)
    }

    console.log(`✅ Match cancelled: ${match_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Match cancelled successfully',
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
```

---

## 4. join-match

**Function Name:** `join-match`

**Code:**
```typescript
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

    if (match.challenger_id !== user.id && match.receiver_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized to join this match' } as ErrorResponse),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (match.remote_status !== 'ready') {
      return new Response(
        JSON.stringify({ error: 'Match is not in ready state' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (match.join_window_expires_at && new Date(match.join_window_expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Join window has expired' } as ErrorResponse),
        { status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const now = new Date()
    const currentPlayerId = match.challenger_id

    const { error: updateError } = await supabaseClient
      .from('matches')
      .update({
        remote_status: 'in_progress',
        current_player_id: currentPlayerId,
        updated_at: now.toISOString(),
      })
      .eq('id', match_id)

    if (updateError) {
      console.error('Match update error:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to join match', details: updateError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { error: lockError } = await supabaseClient
      .from('remote_match_locks')
      .update({ lock_status: 'in_progress' })
      .eq('match_id', match_id)

    if (lockError) {
      console.error('Lock update error:', lockError)
    }

    console.log(`✅ Match joined: ${match_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: { current_player_id: currentPlayerId },
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
```

---

## 5. save-visit (Optional - for gameplay)

**Function Name:** `save-visit`

This function is for saving turns during gameplay. Deploy this later when you're ready to test actual gameplay.

---

## Deployment Order

1. **Start with `accept-challenge`** - This fixes your immediate 404 error
2. Test accepting a challenge
3. Deploy `create-challenge` - For creating new challenges
4. Deploy `cancel-match` - For canceling matches
5. Deploy `join-match` - For joining ready matches
6. Deploy `save-visit` - When ready for gameplay testing

---

## After Deploying accept-challenge

1. Refresh your Supabase dashboard
2. Verify function appears in Edge Functions list
3. Test in your app:
   - Have receiver tap "Accept" on a challenge
   - Should transition to "Ready" state
   - Both users should see "Match Ready" section
   - No more 404 error!

---

## Troubleshooting

- **Still getting 404?** Wait 30-60 seconds for deployment to propagate
- **Deployment fails?** Check for syntax errors in the code
- **Function works but errors?** Check function logs in Supabase dashboard
