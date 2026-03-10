// Edge Function: send-push-notification
// Sends push notifications to users via APNs
// Invoked explicitly from other edge functions (accept-challenge, create-challenge)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Types
interface ErrorResponse {
  error: string
  details?: any
}

interface SuccessResponse {
  success: boolean
  data?: any
  message?: string
}

// APNs configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID') ?? ''
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID') ?? ''
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? ''
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY') ?? ''

// APNs endpoints
const APNS_SANDBOX_URL = 'https://api.sandbox.push.apple.com'
const APNS_PRODUCTION_URL = 'https://api.push.apple.com'

interface PushPayload {
  user_id: string
  notification_type: 'challenge_received' | 'match_ready'
  match_id: string
  title: string
  body: string
  route?: string
  highlight?: string
}

interface PushToken {
  id: string
  user_id: string
  device_install_id: string
  push_token: string
  provider: string
  environment: string
  is_active: boolean
  created_at: string
  updated_at: string
}

serve(async (req) => {
  console.log('📥 [Push] Request received:', req.method)
  
  if (req.method === 'OPTIONS') {
    console.log('✅ [Push] CORS preflight')
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    console.log('🔑 [Push] Auth header present:', !!authHeader)
    console.log('🔑 [Push] Auth header preview:', authHeader?.substring(0, 20) + '...')
    
    // Create Supabase client for authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader! },
        },
      }
    )

    console.log('🔍 [Push] Calling auth.getUser()...')
    
    // Verify caller is authenticated
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    console.log('👤 [Push] User result:', { hasUser: !!user, hasError: !!userError })
    if (userError) {
      console.error('❌ [Push] Auth error:', JSON.stringify(userError))
    }
    if (user) {
      console.log('✅ [Push] Authenticated user:', user.id)
    }

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: userError } as ErrorResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client for database operations (service role for cross-user access)
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload: PushPayload = await req.json()

    // Validate required fields
    if (!payload.user_id || !payload.notification_type || !payload.match_id || !payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id, notification_type, match_id, title, body' } as ErrorResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📤 [Push] Sending ${payload.notification_type} to user ${payload.user_id.substring(0, 8)}... for match ${payload.match_id.substring(0, 8)}...`)

    // Load active push tokens for target user
    const { data: tokens, error: tokensError } = await adminClient
      .from('push_tokens')
      .select('*')
      .eq('user_id', payload.user_id)
      .eq('is_active', true)

    if (tokensError) {
      console.error('❌ [Push] Failed to load tokens:', tokensError)
      return new Response(
        JSON.stringify({ error: 'Failed to load push tokens', details: tokensError } as ErrorResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ [Push] No active tokens found for user ${payload.user_id.substring(0, 8)}...`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No active tokens to send to',
          tokens_sent: 0
        } as SuccessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 [Push] Found ${tokens.length} active token(s)`)

    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        sound: 'default',
        badge: 1,
      },
      type: payload.notification_type,
      matchId: payload.match_id,
      route: payload.route || 'remote',
      highlight: payload.highlight || (payload.notification_type === 'challenge_received' ? 'incoming' : 'ready'),
    }

    const results = []
    let successCount = 0
    let failureCount = 0

    // Send to each token
    for (const token of tokens as PushToken[]) {
      try {
        const result = await sendAPNs(token, apnsPayload, payload.match_id)
        results.push(result)
        
        if (result.success) {
          successCount++
          console.log(`✅ [Push] Sent to device ${token.device_install_id.substring(0, 8)}... (${token.environment})`)
        } else {
          failureCount++
          console.error(`❌ [Push] Failed to send to device ${token.device_install_id.substring(0, 8)}...:`, result.error)
          
          // Handle invalid token (410 Gone from APNs)
          if (result.status === 410) {
            console.log(`🗑️ [Push] Deactivating invalid token for device ${token.device_install_id.substring(0, 8)}...`)
            await adminClient
              .from('push_tokens')
              .update({ is_active: false })
              .eq('id', token.id)
          }
        }

        // Log delivery attempt
        await adminClient
          .from('push_delivery_log')
          .insert({
            user_id: payload.user_id,
            match_id: payload.match_id,
            notification_type: payload.notification_type,
            device_install_id: token.device_install_id,
            push_token_id: token.id,
            status: result.success ? 'sent' : 'failed',
            apns_status_code: result.status,
            error_message: result.error,
            payload: apnsPayload,
          })

      } catch (error) {
        failureCount++
        console.error(`❌ [Push] Exception sending to device ${token.device_install_id.substring(0, 8)}...:`, error)
        results.push({ success: false, error: String(error) })
      }
    }

    console.log(`📊 [Push] Results: ${successCount} sent, ${failureCount} failed`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Push sent to ${successCount} of ${tokens.length} device(s)`,
        tokens_sent: successCount,
        tokens_failed: failureCount,
        results: results,
      } as SuccessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ [Push] Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: String(error) } as ErrorResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Send push notification via APNs
async function sendAPNs(token: PushToken, payload: any, matchId: string): Promise<{ success: boolean; status?: number; error?: string }> {
  try {
    // Generate JWT for APNs authentication
    const jwt = await generateAPNsJWT()
    
    // Select endpoint based on environment
    const apnsUrl = token.environment === 'production' ? APNS_PRODUCTION_URL : APNS_SANDBOX_URL
    const endpoint = `${apnsUrl}/3/device/${token.push_token}`
    
    // Send request to APNs
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': APNS_BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'apns-collapse-id': `match-${matchId}`, // Dedupe by match
      },
      body: JSON.stringify(payload),
    })

    if (response.ok) {
      return { success: true, status: response.status }
    } else {
      const errorBody = await response.text()
      return { 
        success: false, 
        status: response.status, 
        error: `APNs error: ${response.status} - ${errorBody}` 
      }
    }

  } catch (error) {
    return { success: false, error: String(error) }
  }
}

// Generate JWT for APNs authentication
async function generateAPNsJWT(): Promise<string> {
  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID,
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: APNS_TEAM_ID,
    iat: now,
  }

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedPayload = base64UrlEncode(JSON.stringify(payload))
  const signingInput = `${encodedHeader}.${encodedPayload}`

  // Sign with ES256 (ECDSA with P-256 and SHA-256)
  const privateKey = await importPrivateKey(APNS_PRIVATE_KEY)
  const signature = await signWithES256(privateKey, signingInput)
  const encodedSignature = base64UrlEncode(signature)

  return `${signingInput}.${encodedSignature}`
}

// Import ECDSA private key from PEM format
async function importPrivateKey(pemKey: string): Promise<CryptoKey> {
  // Remove PEM header/footer and whitespace
  const pemContents = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')

  // Decode base64
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  // Import as ECDSA P-256 key
  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'ECDSA',
      namedCurve: 'P-256',
    },
    false,
    ['sign']
  )
}

// Sign data with ES256
async function signWithES256(key: CryptoKey, data: string): Promise<string> {
  const encoder = new TextEncoder()
  const dataBuffer = encoder.encode(data)

  const signatureBuffer = await crypto.subtle.sign(
    {
      name: 'ECDSA',
      hash: { name: 'SHA-256' },
    },
    key,
    dataBuffer
  )

  return arrayBufferToString(signatureBuffer)
}

// Base64 URL encode
function base64UrlEncode(str: string): string {
  const base64 = btoa(str)
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}

// Convert ArrayBuffer to string
function arrayBufferToString(buffer: ArrayBuffer): string {
  return String.fromCharCode(...new Uint8Array(buffer))
}
