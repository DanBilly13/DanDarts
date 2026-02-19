// Shared types for Remote Matches Edge Functions

export type RemoteMatchStatus = 
  | 'pending'
  | 'ready'
  | 'lobby'
  | 'in_progress'
  | 'completed'
  | 'expired'
  | 'cancelled'

export interface RemoteMatch {
  id: string
  match_mode: 'local' | 'remote'
  game_type: string
  game_name: string
  match_format: number
  challenger_id: string
  receiver_id: string
  remote_status: RemoteMatchStatus | null
  current_player_id: string | null
  join_window_expires_at: string | null
  challenge_expires_at: string | null
  last_visit_payload: any | null
  created_at: string
  updated_at: string
}

export interface RemoteMatchLock {
  user_id: string
  match_id: string
  lock_status: 'ready' | 'in_progress'
  updated_at: string
}

export interface ErrorResponse {
  error: string
  details?: any
}

export interface SuccessResponse {
  success: boolean
  data?: any
  message?: string
}
