---
trigger: manual
---

# DanDarts — Software Requirements Specification (SRS)

## System Design
**Goal:**  
DanDarts is a native iOS app (built in Swift + SwiftUI) that allows players to play, track, and record darts games — locally or with friends.  
It supports guest players (local only), connected players (via Supabase), and syncing match data after each game.  
It also supports Google Sign-In, local avatars, and a future ad-based monetization model.

**Core subsystems:**
- UI Layer — SwiftUI screens and components
- Domain Logic — game rules, scoring, and checkout calculation
- Local Persistence — Core Data cache for offline play and guest players
- Remote Backend — Supabase (Auth, Postgres DB, Storage)
- Sync Manager — post-game one-way sync (client → Supabase)
- Media Module — image picker and Supabase Storage upload
- Ads (future) — placeholder system, not active in MVP

---

## Architecture Pattern
**MVVM (Model-View-ViewModel)** — for clear separation and testability.  
**Coordinator (lightweight)** pattern handles navigation between routes.

**Layering:**
- Presentation: SwiftUI Views + ViewModels  
- Domain: Game engine, rules, validation logic  
- Data: Repositories (LocalRepo + RemoteRepo)  
- Infrastructure: NetworkClient (Supabase SDK / REST), Image upload, Auth

---

## State Management
- `@StateObject` / `@ObservedObject` ViewModels for reactive data
- Shared global `AppState` object (auth state, active match, friend list)
- Transient UI handled with `@State`
- Async operations with Swift Concurrency (`async/await`)
- Conflict rule: last-write-wins for synced matches
- Game edits allowed only for **last turn**

---

## Data Flow
1. User performs an action (throw input, score save)
2. ViewModel updates domain model and validates turn
3. LocalRepo stores turn data in Core Data
4. On game completion → sync payload to Supabase
5. RemoteRepo uploads match, throws, and updates user stats
6. Friends and profiles fetched via Supabase API and cached locally
7. Avatars uploaded to Supabase Storage; URLs stored in profile
8. Works fully offline; sync resumes automatically when online

---

## Technical Stack
- **Language:** Swift (5.7+)
- **Framework:** SwiftUI
- **Local Storage:** Core Data
- **Backend:** Supabase (Postgres, Auth, Storage)
- **Networking:** Supabase Swift SDK / URLSession
- **Testing:** XCTest, XCUITest
- **Optional:** Firebase Crashlytics or Supabase logs for analytics
- **CI/CD:** GitHub Actions or Bitrise
- **UI Style:** Native Apple components, Apple Human Interface Guidelines, Dark Mode supported

---

## Authentication Process
- **Guest Mode:** creates local-only player profile stored in Core Data
- **Google Sign-In (Supabase OAuth):**
  - On success → fetch or create user in `users` table
  - Tokens handled by Supabase SDK
  - Friends and match history loaded after login
- **Account Linking:** guest can later link to Supabase account
- **Security:** JWT tokens, HTTPS, no sensitive data stored locally

---

## Route Design
**App navigation flow:**
- Splash / Onboarding (optional)
- Home → Game Details → Gameplay → End Game Summary  
- Profile → Edit Profile  
- Friends → Search → Friend Profile → Add / Accept  
- Login / Sign-Up / Continue as Guest  

**Implementation:** SwiftUI `NavigationStack` or lightweight Coordinator with typed routes.

---

## API Design
Supabase (PostgREST) used for CRUD and RPC calls.

**Endpoints:**
- `GET /users?search=` — search by display name, nickname, or handle  
- `POST /users` — create profile  
- `PUT /users/{id}` — update profile or avatar  
- `POST /matches` — upload finished match data  
- `POST /match_throws` — upload turn data  
- `GET /matches?user_id=` — get user match history  
- `POST /friends` — send friend request  
- `PUT /friends/{id}` — accept/reject  
- `GET /friends?user_id=` — list friends  
- `POST /storage/v1/object/{bucket}` — upload avatar image

**Example payloads:**

`POST /matches`
```json
{
  "game_type": "301",
  "players": [
    { "player_id": "uuid", "order": 0 }
  ],
  "started_at": "2025-10-10T20:00:00Z",
  "ended_at": "2025-10-10T20:20:00Z",
  "winner_id": "uuid",
  "metadata": { "duration_seconds": 1200 }
}