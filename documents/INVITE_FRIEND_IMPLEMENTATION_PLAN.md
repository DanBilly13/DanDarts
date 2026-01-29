# Invite Friend (Link-Based) — Implementation Plan (Safe, Stepwise)

## Goal
Add the ability to invite a friend via a shareable link and connect via a **pending** friend request.

- One-time invite token
- Token expires after **7 days**
- Claim creates a `friendships` row with:
  - `status = 'pending'`
  - `requester_id = invitee`
  - `addressee_id = inviter`

This feature should be implemented in small milestones. **After each milestone, run the app and verify existing features still work**.

---

## Milestone 0 — Baseline Safety Check (No Code Changes)

### What you do
- Pull latest `main`
- Build + run the app in Xcode

### Verify
- Friends tab loads
- Friend search still works
- Sending friend requests still works
- FriendRequestsView still works (accept/deny/withdraw)
- Blocked users view still loads

---

## Milestone A — Supabase Backend (Schema + Security + Atomic Claim)

### A1. Add new migration
Create a new SQL migration:
- Create table `public.invites`
- Enable RLS
- Add indexes

Suggested columns:
- `id uuid primary key default gen_random_uuid()`
- `token text not null unique`
- `inviter_id uuid not null references public.users(id) on delete cascade`
- `claimed_by uuid null references public.users(id) on delete set null`
- `created_at timestamptz not null default now()`
- `claimed_at timestamptz null`
- `expires_at timestamptz not null default (now() + interval '7 days')`

### A2. RLS Policies
- INSERT: authenticated user can insert only if `inviter_id = auth.uid()`
- SELECT: inviter can list their own invites
- Avoid exposing token lookups via SELECT; prefer RPC for claim.

### A3. Add RPC: `claim_invite(p_token text)`
Atomic function should:
- Validate token exists
- Validate not expired (`expires_at > now()`)
- Validate not already claimed
- Validate not self-invite
- Validate no blocked relationship exists either direction
- Validate no existing friendship exists either direction
- Mark invite claimed (`claimed_by = auth.uid()`, `claimed_at = now()`)
- Insert `friendships` pending request (invitee -> inviter)

Return a small payload:
- `result` (e.g. `claimed`, `expired`, `already_used`, `blocked`, `already_friends`, `pending_exists`, `invalid`)
- `inviter_id`

### Verify (after applying migration)
- App still builds and runs (no code changes yet)
- Existing friend request features still work

Rollback:
- Drop RPC
- Drop invites table

---

## Milestone B — iOS Deep Link Plumbing (URL Scheme + Token Storage)

### B1. Add URL Scheme
Add `dandarts` scheme so links like:
- `dandarts://invite?token=...`
open the app.

### B2. Parse URL + store token
Add a tiny store:
- `PendingInviteStore.set(token:)`
- `PendingInviteStore.consumeToken()`
Persist to `UserDefaults` to survive restart.

### B3. Route to Claim UI
- If authenticated: navigate to invite claim UI
- If not authenticated: store token and route to claim UI after auth completes

### Verify
- App launches normally
- Existing navigation still works
- If you paste a sample URL into Safari Notes and tap:
  - app opens (even if claim UI is stub)

---

## Milestone C — Inviter UI (Create Invite + Share Sheet)

### C1. InviteService.createInvite()
- Generates token (client-side random)
- Inserts into `invites`
- Builds URL `dandarts://invite?token=...`

### C2. FriendsListView "Invite Friend" button
- Tap -> create invite -> present share sheet

### Verify
- Friends tab still loads
- Invite button opens share sheet
- Sending existing friend requests is unaffected

---

## Milestone D — Invite Claim UI + Claim Integration

### D1. InviteClaimView
- Shows inviter identity (may load after claim result)
- CTA: "Send Friend Request"
- Secondary: "Not Now"

### D2. InviteService.claimInvite(token:)
- Calls Supabase RPC `claim_invite`
- Maps response to UI states

### D3. Post-claim UI sync
- On success: dismiss claim UI
- Refresh pending request counts / views (if applicable)

### Verify
- Invitee can claim and create pending request
- Inviter sees it in Received Requests
- Accept/deny still behaves the same

---

## Milestone E — Full Regression Test Matrix

### Scenarios
- Signed-in invitee claims token
- Signed-out invitee claims token (after sign-in)
- Expired token
- Token already claimed
- Already friends
- Pending request already exists
- Blocked either direction

### Verify no regressions
- Friend search
- Send request
- Requests view (accept/deny/withdraw)
- Block/unblock
- Badge counts (if enabled)

---

## Notes / Design Decisions
- The app does **not** know where the user sent the invite (Messages/WhatsApp/etc.).
- The share sheet destination is controlled by iOS and the user.
- We only track:
  - invite created (inviter)
  - invite claimed (claimed_by)

