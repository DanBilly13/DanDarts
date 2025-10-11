---
trigger: manual
---

# DanDarts — Software Requirements Specification

## System Design

### Overview
DanDarts is a native iOS app built with SwiftUI, targeting casual dart players who want automated scoring and social play tracking. The system consists of a Swift frontend with local-first data storage and Supabase backend for authentication and cloud sync.

### Core Modules
- **Authentication Module:** User registration, login, session management
- **Game Engine Module:** Score calculation, game rules, turn management
- **Player Management Module:** Local guests and connected friends
- **Social Module:** Friend search, match history, head-to-head stats
- **Sync Module:** Background data sync with Supabase

### Data Strategy
- **Local-First:** All gameplay works offline using local storage
- **Sync on Demand:** Data syncs to Supabase after game completion
- **Conflict Resolution:** Last-write-wins for MVP (user device timestamp)

---

## Architecture Pattern

### MVVM-Light
Simple MVVM using SwiftUI's native reactive features without heavy frameworks.

**Structure:**
```
View (SwiftUI) → ViewModel (@ObservableObject) → Model/Service
```

**Components:**
- **Views:** SwiftUI views (pure UI, no business logic)
- **ViewModels:** @ObservableObject classes with @Published properties
- **Models:** Swift structs for data (Codable for persistence)
- **Services:** Singletons for API, database, auth (async/await)

**Benefits:**
- Easy to understand and debug
- Perfect for AI-assisted coding
- Native SwiftUI patterns
- Scales well for MVP scope

---

## State Management

### SwiftUI Native State
- **@State:** Local view state (temporary UI state)
- **@StateObject:** ViewModel ownership in view
- **@ObservedObject:** ViewModel observation from parent
- **@EnvironmentObject:** Shared services (AuthService, GameService)
- **@Published:** Observable properties in ViewModels

### State Flow
```
User Action → View → ViewModel Method → Service Call → Model Update → @Published triggers → View Refresh
```

### Shared State (Environment Objects)
- **AuthService:** Current user session, login state
- **PlayerService:** Friends list, player profiles
- **GameService:** Active game state during gameplay

### Local Persistence
- **UserDefaults:** Simple settings (sound on/off, last user)
- **FileManager (JSON):** Local players, guest profiles, cached games
- **Keychain:** Supabase session tokens

---

## Data Flow

### Offline First Flow
```
User Input → Local State Update → UI Refresh → Queue for Sync
```

### Online Sync Flow
```
Game Complete → Local Save → Background Sync → Supabase Update → Confirmation
```

### Friend Search Flow
```
Search Query → Debounced Input → Supabase API Call → Results Display
```

### Authentication Flow
```
Login → Supabase Auth → Token Storage → Fetch User Profile → Navigate to Home
```

### Gameplay Flow
```
Start Game → Load Rules → Initialize Players → Score Input Loop → Calculate Winner → Save Results → Sync
```

---

## Technical Stack

### Frontend
- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Minimum iOS:** 17.0
- **IDE:** Xcode 15+

### Backend
- **BaaS:** Supabase (PostgreSQL + Auth + Storage)
- **Authentication:** Supabase Auth with Google OAuth
- **Database:** PostgreSQL (via Supabase)
- **API:** Supabase REST API + Realtime (future)

### Dependencies (SPM)
- **supabase-swift:** Official Supabase client SDK

### Development Tools
- Xcode 15+
- Xcode Previews for rapid UI iteration
- Windsurf AI + Claude for pair programming
- TestFlight for beta distribution

### Asset Management
- SF Symbols for all icons
- Native Image assets for avatars
- Color assets in Xcode catalog

---

## Authentication Process

### Registration Flow
1. User taps "Sign Up" on Welcome screen
2. Enters display name, nickname, email, password
3. Validates nickname uniqueness via Supabase query
4. Calls `supabase.auth.signUp(email:password:)`
5. Creates profile record in `profiles` table
6. Navigates to Profile Setup for avatar
7. Stores session token in Keychain
8. Navigates to Games tab

### Sign In Flow
1. User taps "Sign In"
2. Enters email and password
3. Calls `supabase.auth.signIn(email:password:)`
4. Retrieves session token
5. Fetches user profile from `profiles` table
6. Stores session in Keychain
7. Navigates to Games tab

### Google Sign In Flow
1. User taps "Sign in with Google"
2. Opens Google OAuth via Supabase
3. Returns with access token
4. Checks if profile exists
5. If new: Navigate to Profile Setup
6. If existing: Navigate to Games tab

### Guest Mode
1. User taps "Continue as Guest"
2. No authentication required
3. Local-only mode (no sync, no friends)
4. Can create local guest players
5. Can upgrade to account later

### Session Management
- Token stored in Keychain (encrypted)
- Auto-refresh on app launch
- Logout clears token and local cache
- Session expires after 7 days (Supabase default)

---

## Route Design

### Navigation Structure
SwiftUI NavigationStack with TabView at root.

### Tab Routes
```
TabView (persistent)
├── GamesTab
├── FriendsTab
└── HistoryTab
```

### Navigation Flows
```
GamesTab
└── NavigationStack
    ├── GameListView (root)
    ├── GameDetailView
    ├── PreGameHypeView
    ├── GameplayView (full screen)
    └── GameEndView

FriendsTab
└── NavigationStack
    ├── FriendsListView (root)
    ├── FriendSearchView
    └── FriendProfileView

HistoryTab
└── NavigationStack
    ├── MatchHistoryView (root)
    └── MatchDetailView
```

### Modal Presentations
```
ProfileView (sheet from avatar tap)
WelcomeView (full screen cover on first launch)
AuthView (full screen cover when not authenticated)
ProfileSetupView (sheet after registration)
```

### Deep Linking (Future)
- `dandarts://game/{gameId}`
- `dandarts://friend/{userId}`

---

## API Design

### Supabase Client Setup
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_PROJECT_URL")!,
    supabaseKey: "YOUR_ANON_KEY"
)
```

### Authentication Endpoints
- `supabase.auth.signUp(email:password:)` → User session
- `supabase.auth.signIn(email:password:)` → User session
- `supabase.auth.signInWithOAuth(provider:)` → OAuth flow
- `supabase.auth.signOut()` → Void
- `supabase.auth.session` → Current session

### Database Queries (REST)
**Profiles:**
- `GET /profiles?id=eq.{userId}` → User profile
- `POST /profiles` → Create profile
- `PATCH /profiles?id=eq.{userId}` → Update profile
- `GET /profiles?nickname=ilike.%{query}%` → Search users

**Friends:**
- `GET /friendships?user_id=eq.{userId}` → User's friends
- `POST /friendships` → Add friend
- `DELETE /friendships?id=eq.{friendshipId}` → Remove friend

**Matches:**
- `GET /matches?or=(player1_id.eq.{userId},player2_id.eq.{userId})` → User's matches
- `POST /matches` → Save match result
- `GET /matches?player1_id=eq.{id1}&player2_id=eq.{id2}` → Head-to-head

**Players (Local Guests):**
- Stored in local JSON file
- No API calls required

### Error Handling
- Network errors: Retry with exponential backoff
- Auth errors: Redirect to login
- Validation errors: Show inline error messages
- Generic errors: Show alert with retry option

---

## Database Design ERD

### Tables

#### profiles
```
id (uuid, PK, references auth.users)
display_name (text, not null)
nickname (text, unique, not null)
avatar_url (text, nullable)
created_at (timestamp, default now())
updated_at (timestamp, default now())
total_wins (int, default 0)
total_losses (int, default 0)
```
**Indexes:** nickname (unique)

#### friendships
```
id (uuid, PK, default gen_random_uuid())
user_id (uuid, FK → profiles.id)
friend_id (uuid, FK → profiles.id)
created_at (timestamp, default now())
status (text, default 'accepted') -- for future friend requests
```
**Indexes:** user_id, friend_id  
**Constraint:** Unique (user_id, friend_id)

#### matches
```
id (uuid, PK, default gen_random_uuid())
game_type (text, not null) -- '301', '501', 'halve-it', etc.
player1_id (uuid, FK → profiles.id)
player2_id (uuid, FK → profiles.id, nullable) -- null if guest
player1_name (text, not null) -- display name
player2_name (text, not null)
winner_id (uuid, nullable) -- null if tie/incomplete
winner_name (text, nullable)
player1_score (int, nullable)
player2_score (int, nullable)
match_data (jsonb, nullable) -- detailed turn-by-turn data
played_at (timestamp, default now())
synced_at (timestamp, nullable)
```
**Indexes:** player1_id, player2_id, played_at, game_type  
**Note:** Support 2 players for MVP (multi-player in future)

#### local_players (File-based, not in Supabase)
```json
{
  "id": "uuid",
  "display_name": "string",
  "nickname": "string",
  "avatar_path": "string",
  "total_wins": 0,
  "total_losses": 0,
  "created_at": "timestamp"
}
```
Stored in: `Documents/local_players.json`

### Relationships
```
profiles 1 ──< ∞ friendships (user_id)
profiles 1 ──< ∞ friendships (friend_id)
profiles 1 ──< ∞ matches (player1_id)
profiles 1 ──< ∞ matches (player2_id)
profiles 1 ──< ∞ matches (winner_id)
```

### Row Level Security (RLS)
**profiles:**
- Users can read all profiles (for search)
- Users can only update their own profile

**friendships:**
- Users can read their own friendships
- Users can insert friendships where they are user_id
- Users can delete their own friendships

**matches:**
- Users can read matches they participated in
- Users can insert matches they participated in
- No updates/deletes (immutable records)

### Database Functions (Future)
- `get_head_to_head(user1_id, user2_id)` → Stats object
- `update_user_stats(user_id)` → Recalculate wins/losses

### Migrations
Use Supabase Migration tool via dashboard or CLI:
1. Create tables with RLS policies
2. Set up indexes
3. Create foreign key constraints
4. Set up auth triggers (auto-create profile on signup)

---

## Additional Technical Considerations

### Performance
- Lazy loading for friends list and history
- Image caching for avatars (URLCache)
- Debounced search input (300ms)
- Pagination for match history (20 per page)

### Security
- API keys in environment variables (not committed)
- Keychain for sensitive data
- RLS policies on all tables
- Input validation on client and server

### Testing Strategy (MVP Light)
- Unit tests for game logic (score calculation, win conditions)
- Manual testing for UI flows
- TestFlight beta before production
- Defer comprehensive testing to post-MVP

### Offline Support
- Queue failed sync operations
- Retry on network reconnect
- Show sync status indicator
- Manual retry button if auto-sync fails

### Future Enhancements Ready
- Realtime subscriptions for live scoring
- Push notifications infrastructure
- Analytics events structure
- Ad integration placeholder code