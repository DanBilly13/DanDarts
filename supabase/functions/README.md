# Remote Matches Edge Functions

Server-authoritative Edge Functions for DanDarts Remote Matches feature.

## Functions

### 1. create-challenge
Creates a new remote match challenge.

**Endpoint:** `POST /create-challenge`

**Request:**
```json
{
  "receiver_id": "uuid",
  "game_type": "301" | "501",
  "match_format": 1 | 3 | 5 | 7
}
```

**Response:**
```json
{
  "success": true,
  "data": { /* match object */ },
  "message": "Challenge created successfully"
}
```

**Validations:**
- User must be authenticated
- Cannot challenge yourself
- User cannot have existing active lock
- Receiver must exist
- Challenge expires in 24 hours

---

### 2. accept-challenge
Accepts a pending challenge and transitions to ready state.

**Endpoint:** `POST /accept-challenge`

**Request:**
```json
{
  "match_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Challenge accepted successfully"
}
```

**Validations:**
- User must be receiver
- Match must be in pending state
- User cannot have existing active lock
- Challenge must not be expired
- Creates locks for both users (ready state)
- Join window: 5 minutes

---

### 3. cancel-match
Cancels a pending or ready match.

**Endpoint:** `POST /cancel-match`

**Request:**
```json
{
  "match_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Match cancelled successfully"
}
```

**Validations:**
- User must be challenger or receiver
- Match must be pending or ready (not in_progress)
- Clears all locks

---

### 4. join-match
Joins a ready match and starts gameplay.

**Endpoint:** `POST /join-match`

**Request:**
```json
{
  "match_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": { "current_player_id": "uuid" },
  "message": "Match joined successfully"
}
```

**Validations:**
- User must be challenger or receiver
- Match must be in ready state
- Join window must not be expired
- Transitions to in_progress
- Updates locks to in_progress
- Challenger goes first

---

### 5. save-visit
Saves a visit (3 darts) with server-side validation.

**Endpoint:** `POST /save-visit`

**Request:**
```json
{
  "match_id": "uuid",
  "darts": [15, 20, 5],
  "score_before": 301,
  "score_after": 261
}
```

**Response:**
```json
{
  "success": true,
  "data": { "next_player_id": "uuid" },
  "message": "Visit saved successfully"
}
```

**Validations:**
- User must be participant
- Match must be in_progress
- Must be user's turn
- Darts must be array of 3 scores
- Stores visit payload for 1-2s reveal animation
- Switches to next player

---

## Deployment

### Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Supabase project created
- Logged in: `supabase login`

### Deploy All Functions
```bash
# Link to your project
supabase link --project-ref your-project-ref

# Deploy all functions
supabase functions deploy create-challenge
supabase functions deploy accept-challenge
supabase functions deploy cancel-match
supabase functions deploy join-match
supabase functions deploy save-visit
```

### Deploy Single Function
```bash
supabase functions deploy create-challenge
```

### Test Locally
```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve

# Test with curl
curl -i --location --request POST 'http://localhost:54321/functions/v1/create-challenge' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"receiver_id":"uuid","game_type":"301","match_format":1}'
```

---

## Configuration

### Environment Variables
Set in Supabase Dashboard > Project Settings > Edge Functions:

- `SUPABASE_URL` - Auto-provided
- `SUPABASE_ANON_KEY` - Auto-provided

### Constants
Defined in each function:

- **Challenge Expiry:** 24 hours (86400 seconds)
- **Join Window:** 5 minutes (300 seconds)

---

## Error Handling

All functions return consistent error responses:

```json
{
  "error": "Error message",
  "details": { /* optional error details */ }
}
```

**Common HTTP Status Codes:**
- `200` - Success
- `400` - Bad Request (validation error)
- `401` - Unauthorized (not authenticated)
- `403` - Forbidden (not authorized for this action)
- `404` - Not Found (resource doesn't exist)
- `409` - Conflict (lock exists, invalid state)
- `410` - Gone (expired)
- `500` - Internal Server Error

---

## Lock Mechanism

The `remote_match_locks` table enforces the "one Ready + one In Progress" rule:

- **Lock Creation:** When challenge is accepted (ready state)
- **Lock Update:** When match is joined (in_progress state)
- **Lock Deletion:** When match is cancelled or completed
- **Lock Check:** Before creating new challenge or accepting challenge

**Lock States:**
- `ready` - Match is ready to join
- `in_progress` - Match is actively being played

---

## Realtime Updates

All match state changes trigger Supabase Realtime updates:

```typescript
// Client subscribes to matches table
supabase
  .channel('remote-matches')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'matches',
    filter: 'match_mode=eq.remote'
  }, (payload) => {
    // Handle update
  })
  .subscribe()
```

---

## TODO

- [ ] Implement push notifications (APNs)
- [ ] Add `expire-matches` cron function
- [ ] Save visits to `match_throws` table for history
- [ ] Add rate limiting
- [ ] Add analytics/logging
