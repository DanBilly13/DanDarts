# Notifications Current State

Comprehensive reference for all notification systems in Dart Freak: Apple Push Notifications (APNs) and in-app notifications for friend requests and remote games.

---

## 1. Executive Summary

Dart Freak has **two parallel notification systems**:

| System | Trigger | Delivery | Use Cases |
|--------|---------|----------|-----------|
| **Apple Push (APNs)** | Server-side Edge Function | iOS banner/sound/badge (background/closed app) | Friend requests, challenge received, match ready |
| **In-App Notifications** | Realtime Postgres changes | Toast overlays, tab badges, card highlighting | Friend request toasts, challenge list updates, badge counts |

**Key rule:** Push notifications are best-effort (non-blocking). In-app notifications are the primary UX. Both update the same badge counts.

---

## 2. Apple Push Notifications (APNs)

### 2.1 Architecture

```
iOS App (Swift)
  ├─ AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken → syncPushToken()
  ├─ NotificationService (UNUserNotificationCenterDelegate)
  │   ├─ Foreground: suppresses banners (completionHandler([]))
  │   └─ Tap: parses payload → NotificationRouteIntent → tab navigation
  └─ SettingsView: toggle on/off → activates/deactivates token in DB

Supabase Edge Function: push-notifications
  ├─ Auth: validates caller JWT
  ├─ Token loading: SELECT * FROM push_tokens WHERE user_id = ? AND is_active = true
  ├─ APNs JWT generation: ES256 signing with P8 private key
  ├─ Environment routing: sandbox vs production endpoint
  ├─ Deduplication: apns-collapse-id header per match
  └─ Delivery logging: INSERT into push_delivery_log
```

### 2.2 Trigger Points (Who Sends Pushes)

Three call sites invoke the `push-notifications` Edge Function:

| Event | Caller | Target | Payload Type |
|-------|--------|--------|--------------|
| Friend request sent | `FriendsService.sendFriendRequest()` (client Swift) | Addressee | `friend_request_received` |
| Challenge created | `create-challenge` Edge Function | Receiver | `challenge_received` |
| Challenge accepted | `accept-challenge` Edge Function | Challenger | `match_ready` |

**Note:** `FriendsService.sendFriendRequest()` calls the Edge Function from the **client side** using `supabaseService.client.functions.invoke("push-notifications", ...)`. The two remote match flows call it **server-to-server** from within Edge Functions.

### 2.3 APNs Payload Structure

```json
{
  "aps": {
    "alert": { "title": "...", "body": "..." },
    "sound": "default",
    "badge": 1
  },
  "type": "challenge_received" | "match_ready" | "friend_request_received",
  "matchId": "uuid",           // OMITTED for friend requests (was a bug, now fixed)
  "route": "remote" | "friends",
  "highlight": "incoming" | "ready" | "friend_request"
}
```

### 2.4 Token Lifecycle

1. **Registration:** iOS system delivers token → `AppDelegate` → `syncPushToken(token)` → upsert `push_tokens` row with `is_active = true`
2. **Per-install tracking:** `device_install_id` stored in UserDefaults. Unique per app install. Enables multi-device users.
3. **Toggle OFF:** Settings toggle → `deactivateCurrentDeviceToken()` → sets `is_active = false`
4. **Toggle ON:** Settings toggle → `activateCurrentDeviceToken()` → sets `is_active = true`, re-registers with APNs if needed
5. **Logout:** `deactivateCurrentDeviceToken()` called, `resetLoadedState()` clears cached state
6. **Invalidation:** Edge Function detects APNs 410 → auto-deactivates token in DB
7. **Retry on reinstall:** `retryTokenSyncIfNeeded()` detects no cached token + iOS authorized → requests fresh token

### 2.5 Environment Detection

`NotificationService.getAPNsEnvironment()` reads the provisioning profile's `aps-environment` entitlement at runtime. Fallback: DEBUG → sandbox, RELEASE → production. This value is stored in `push_tokens.environment` and used by the Edge Function to route to the correct APNs endpoint.

### 2.6 Foreground Policy

When the app is in foreground, `userNotificationCenter(_:willPresent:)` returns `completionHandler([])` — **no banner is shown**. The in-app realtime system handles the UX instead. Taps while the app is active are ignored (comment says "Foreground policy (Phase 8)").

---

## 3. In-App Notifications

### 3.1 Friend Request In-App Flow

**Realtime subscription:** `FriendsService.setupRealtimeSubscription()` subscribes to `public:friendships` Postgres changes with client-side filtering for the current user.

| DB Event | Toast Shown | Target User |
|----------|-------------|-------------|
| INSERT (new request) | `requestReceived` toast with Accept/Deny buttons | Addressee |
| UPDATE (status → accepted) | `requestAccepted` toast | Requester |
| DELETE (denied/withdrawn) | `requestDenied` toast | Requester |

**Toast suppression:** When the user is on the Friends tab (`selectedTab == 1`), `FriendRequestToastManager.suppressRequestReceivedToasts = true` prevents incoming request toasts from appearing. Accepted/denied toasts still show.

**Catch-up on app return:** `checkForPendingRequestsOnReturn()` queries for the most recent pending request and shows a delayed toast with `animationConfig.initialDelay` (bouncy config = 0.6s).

**Badge updates:** Every friendship change posts `NotificationCenter.Name("FriendRequestsChanged")`, which `MainTabView` listens to and calls `loadPendingRequestCount()` → queries DB for pending received requests → updates `pendingRequestCount` → renders `.badge(pendingRequestCount)` on Friends tab.

### 3.2 Remote Game In-App Flow

**Realtime subscription:** `RemoteMatchService.setupRealtimeSubscription()` subscribes to `public:matches` Postgres changes, filtered to remote matches where the user is challenger or receiver.

On INSERT/UPDATE:
- `scheduleListReload(userId:)` throttles reloads (400ms) to avoid flash
- `scheduleFlowMatchFetch(matchId:)` updates active match state if in remote flow
- Posts `NotificationCenter.Name("RemoteChallengesChanged")`

**Badge updates:** `MainTabView` listens for `RemoteChallengesChanged` and calls `loadPendingChallengeCount()` → `RemoteMatchService.getPendingChallengeCount()` queries `matches` where `receiver_id = userId AND remote_status = 'pending'` → updates `pendingChallengeCount` → renders `.badge(pendingChallengeCount)` on Remote tab.

**Declined match detection:** `RemoteGamesTab` uses `onReceive(remoteMatchService.$sentChallenges)` to detect when a previously known sent challenge disappears → shows a declined toast via `declinedMatchesCache`.

### 3.3 Toast Systems

There are **two independent toast managers**:

1. **`FriendRequestToastManager`** — friend request specific
   - Interactive: `requestReceived` has Accept/Deny buttons (no auto-dismiss)
   - Auto-dismiss: `requestAccepted`, `requestDenied` dismiss after 3.5s
   - Queueing: toasts queue if one is already showing
   - Haptic feedback on display

2. **`ToastManager`** — generic ephemeral toasts
   - Used for match decline/cancel/success messages
   - Auto-dismiss after 2.5s
   - Centered overlay with SF Symbol + message

---

## 4. Notification Permission Flow

### 4.1 Onboarding

`PermissionsOnboardingView` is shown after sign-up/profile setup.
- User sees two toggles: Notifications (default ON), Voice Chat (default ON)
- Tapping "Done" requests permissions **sequentially**
- If notifications intent is ON: calls `NotificationService.setNotificationsEnabled(true)` which may trigger iOS permission dialog

### 4.2 Settings

`SettingsView` shows a Notifications toggle that reflects the DB state (`hasLoadedState` prevents animation flash on first appear).
- **Toggle ON:** checks authorization status → requests permission if notDetermined → syncs/activates token
- **Toggle OFF:** deactivates token in DB
- **Denied state:** shows alert with "Open Settings" button that opens iOS Settings app

### 4.3 Auto-recovery

- `retryTokenSyncIfNeeded()` called on `MainTabView.onAppear` — recovers from delete+reinstall by requesting a fresh APNs token if iOS still considers the user authorized
- Token stored in UserDefaults under key `"apns_device_token"` for retry purposes

---

## 5. Deep Linking from Push Taps

### 5.1 Payload Parsing

`NotificationPayloadParser.parseIntent()` extracts:
- `type` → destination and highlight style
- `matchId` / `match_id` / `matchID` → optional UUID
- `highlight` → `.incoming`, `.ready`, `.friendRequest`

### 5.2 Routing

`NotificationRouteIntent` has two destinations:
- `.remoteTab` → `MainTabView.selectedTab = 2`
- `.friendsTab` → `MainTabView.selectedTab = 1`

For remote tab taps with a `matchId`:
- `RemoteNotificationIntentConsumer.consume()` loads matches, checks if match exists in lists, scrolls to it, highlights the card for 1.25s

### 5.3 App State Handling

- **App closed/background:** tap opens app, `handleNotificationTap()` sets `pendingIntent`, `MainTabView.onChange` routes to correct tab
- **App foreground:** tap is **ignored** (Phase 8 contract). Rely on in-app UI instead.

---

## 6. Database Schema

### 6.1 `push_tokens` (Migration 068)

```sql
CREATE TABLE public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_install_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  provider TEXT NOT NULL DEFAULT 'apns',
  environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
  push_token TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ,
  UNIQUE(user_id, device_install_id)
);
```

RLS policies: users can only view/insert/update/delete their own tokens.

**Legacy table:** `user_push_tokens` (Migration 047) — do not use for new code.

### 6.2 `push_delivery_log` (Migration 069)

```sql
CREATE TABLE public.push_delivery_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dedupe_key TEXT NOT NULL,
  match_id UUID NOT NULL,
  recipient_user_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  success BOOLEAN NOT NULL,
  error_message TEXT,
  UNIQUE(dedupe_key)
);
```

RLS: service_role only (Edge Functions).

**Note:** The Edge Function `push-notifications/index.ts` inserts slightly different columns (`user_id`, `match_id`, `notification_type`, `device_install_id`, `push_token_id`, `status`, `apns_status_code`, `error_message`, `payload`) than what the migration defines. The actual table schema in production may differ from the migration file.

---

## 7. File Reference Map

### Client (iOS/Swift)

| File | Role |
|------|------|
| `DartFreakApp.swift` | AppDelegate: receives APNs token, syncs to Supabase; sets UNUserNotificationCenter delegate |
| `Services/NotificationService.swift` | Singleton: permission requests, token sync, toggle on/off, deep-link intent handling, environment detection |
| `Services/NotificationPayloadParser.swift` | Parses push notification payload → `NotificationRouteIntent` |
| `Services/FriendRequestToastManager.swift` | Singleton: queues and displays friend request toasts |
| `Services/FriendsService.swift` | Realtime subscription on `friendships`; triggers push on `sendFriendRequest`; handles badge count query |
| `Services/RemoteMatchService.swift` | Realtime subscription on `matches`; handles badge count query (`getPendingChallengeCount`) |
| `Services/ToastManager.swift` | Generic ephemeral toast manager |
| `Views/MainTabView.swift` | Badge rendering, `FriendRequestsChanged`/`RemoteChallengesChanged` listeners, toast container overlay, intent routing |
| `Views/Remote/RemoteGamesTab.swift` | Notification intent consumption: loads matches, scrolls to card, highlights |
| `Views/Remote/RemoteNotificationIntentConsumer.swift` | Helper that consumes intent by loading matches, scrolling, highlighting |
| `Views/Components/FriendRequestToastView.swift` | UI for friend request toasts (with Accept/Deny buttons) |
| `Views/Components/ToastView.swift` | Generic toast UI component |
| `Views/Auth/PermissionsOnboardingView.swift` | Onboarding screen for notification + voice permissions |
| `Views/Profile/SettingsView.swift` | Notifications toggle with DB-backed state, permission denied alert |

### Server (Supabase Edge Functions)

| File | Role |
|------|------|
| `supabase/functions/push-notifications/index.ts` | APNs delivery: JWT auth, token loading, multi-device send, 410 handling, delivery logging |
| `supabase/functions/create-challenge/index.ts` | Sends `challenge_received` push to receiver after creating match |
| `supabase/functions/accept-challenge/index.ts` | Sends `match_ready` push to challenger after acceptance |

### Database Migrations

| File | Role |
|------|------|
| `supabase_migrations/068_create_push_tokens_table.sql` | `push_tokens` schema |
| `supabase_migrations/069_create_push_delivery_log_table.sql` | `push_delivery_log` schema |
| `supabase_migrations/047_remote_matches_schema.sql` | Legacy `user_push_tokens` (unused) |

---

## 8. Known Behaviors & Limitations

### 8.1 Push Notifications

- **Best-effort:** All push sends are non-blocking. Failure does not fail the primary operation (friend request creation, challenge creation, challenge acceptance).
- **No retry logic:** Transient APNs failures are not retried automatically.
- **No rate limiting:** A user could theoretically be spammed with pushes.
- **Badge = 1:** APNs payload always sets badge to 1, not the actual pending count. The app recalculates the real badge when opened via in-app queries.
- **Simulator:** APNs does not work in simulator; `didFailToRegisterForRemoteNotificationsWithError` logs a normal failure.

### 8.2 In-App Notifications

- **Realtime lag:** Supabase Realtime has inherent latency. Toast may appear a few seconds after the DB change.
- **Foreground suppression:** Friend request received toasts are suppressed when the user is already on the Friends tab.
- **Badge sound:** `AudioServicesPlaySystemSound(1007)` plays on badge count increase in `MainTabView`.

### 8.3 Historical Bug (Fixed)

The Edge Function originally sent `matchId: undefined` for friend request pushes because it always included `matchId: payload.match_id` unconditionally. APNs rejected the malformed payload → sound played but no banner. Fix: `...(payload.match_id && { matchId: payload.match_id })`.

---

## 9. Notification Type Reference

| Type | Trigger | Push Target | In-App Target | Deep Link |
|------|---------|-------------|---------------|-----------|
| `friend_request_received` | `sendFriendRequest()` | Addressee | Addressee (toast + badge) | Friends tab |
| `challenge_received` | `create-challenge` Edge Function | Receiver | Receiver (card in list + badge) | Remote tab, scroll to incoming |
| `match_ready` | `accept-challenge` Edge Function | Challenger | Challenger (card in list + badge) | Remote tab, scroll to ready |

---

## 10. Testing Checklist

### Push Notifications
- [ ] Fresh install → onboarding → enable notifications → token appears in `push_tokens` with `is_active = true`
- [ ] Send friend request → receiver gets push with banner (app background)
- [ ] Create challenge → receiver gets push with banner (app background)
- [ ] Accept challenge → challenger gets push with banner (app background)
- [ ] Tap push notification → app opens to correct tab
- [ ] Settings toggle OFF → `is_active` becomes `false`
- [ ] Settings toggle ON → `is_active` becomes `true`
- [ ] Logout → token deactivated
- [ ] Delete app, reinstall, login → `retryTokenSyncIfNeeded` recovers token

### In-App Notifications
- [ ] Send friend request (receiver app foreground) → toast appears with Accept/Deny
- [ ] Accept friend request (requester app foreground) → toast appears
- [ ] Decline friend request (requester app foreground) → toast appears
- [ ] Friends tab badge updates when request received
- [ ] Remote tab badge updates when challenge received
- [ ] Realtime update shows new challenge card without pull-to-refresh
- [ ] Declined challenge shows toast in sender's app

---

*Last updated: 2026-06-10*
