---
trigger: manual
---

# 🎯 DanDarts — Product Requirements Document (PRD)

## 1. Elevator Pitch  
**DanDarts** is a Swift-based iOS app for casual dart players who want to focus on the fun, not the math. It automatically tracks scores, calculates finishes, and provides access to classic and lesser-known dart games. Players compete locally or connect with friends online, tracking head-to-head stats with a simple, pub-style experience.

---

## 2. Target Users  
- Casual dart players (ages 15-55) at home or in pubs
- Small groups of friends who play together regularly
- Users who want intuitive scoring without complex setup
- Players who enjoy stats and friendly rivalries

---

## 3. Core Features  

### Game Modes (MVP)
- 301, 501, Halve-It, Knockout, Sudden Death, English Cricket, Killer
- Automatic scoring and checkout calculation
- Game instructions for each mode
- Expandable architecture for future games

### Authentication & Players
- Email/password registration and sign-in
- Google OAuth via Supabase
- Guest mode (local-only, no sync)
- Player types: Guest (local) and Connected (Supabase account)
- Profile: Display name, nickname (@handle), avatar, win/loss stats

### Gameplay Experience
- **Pre-Game Hype Screen:** Boxing match style with avatars, "VS", head-to-head stats, bell sound, "GET READY!" text, auto-start after 2-3 seconds
- **Score Input:** Tap number for single, long-press for Double/Triple, "Miss" button, "Save Score" to end turn
- **Edit:** Last turn only
- **Audio:** Sound effects per throw, "180!" voice callout, toggleable in settings
- **Exit:** Mid-game exit with confirmation
- **End Game:** Winner display, celebration animation, "Play Again", "New Game", "Change Players" options

### Social & History
- **Friends:** Search by name/nickname, add friends, view friends list, remove friends
- **Match History:** Filter by game type or opponent, detailed results, date stamps
- **Head-to-Head Stats:** Win/loss records between specific players
- **Data Sync:** Automatic sync to Supabase after each game (offline mode supported)

### Navigation
- **Top Bar:** App logo (left), profile avatar (right) → opens Profile & Settings
- **Bottom Tabs:** Games, Friends, History
- **Profile & Settings:** User info, stats, sound toggle, notifications, change password/email, privacy/terms links, logout, delete account

---

## 4. Key User Stories  

Users want to:
- Browse and pick games quickly with clear rules
- See a hype screen before matches for excitement
- Add players easily (manual guests or connected friends)
- Record scores via taps/holds without thinking
- Undo mistakes (last turn only)
- Exit games mid-match if needed
- View friends list and search for new friends
- See match history and head-to-head stats
- Hear sound effects that can be toggled
- Celebrate wins with animations and easy rematches
- Access profile/settings from any screen
- Sync data automatically across devices
- Play offline without limitations

---

## 5. User Interface Essentials

### Screens
- **Splash/Loading:** App logo, checks auth state
- **Welcome:** Sign In, Sign Up, Continue as Guest
- **Sign In/Register:** Email/password or Google OAuth
- **Profile Setup:** Avatar selection, confirm name/nickname
- **Games Tab:** Horizontal game card carousel
- **Game Details:** Rules, player selection, "Start Game"
- **Pre-Game Hype:** Boxing match style with animations
- **Gameplay:** Active player highlighted, circular scoring buttons, score summary
- **Game End:** Winner, celebration, action buttons
- **Friends Tab:** Friends list, search, add friend
- **History Tab:** Past matches, filterable results
- **Profile & Settings:** User info, stats, settings, logout

### Navigation Flow
```
Launch → Splash → Auth Check
    ├── Has Session → Games Tab
    └── No Session → Welcome
            ├── Sign In → Games Tab
            ├── Sign Up → Profile Setup → Games Tab
            └── Guest → Games Tab (local mode)

Start Game → Game Details → Add Players → Hype Screen → Gameplay → End Screen
```

---

## 6. Technical Requirements  

### Platform
- iOS 17+ (iPhone)
- Swift + SwiftUI
- Supabase backend (PostgreSQL, Auth, Storage)
- Local-first with background sync

### Architecture
- MVVM-Light pattern
- Native SwiftUI state management
- async/await (no Combine)
- Minimal dependencies (Supabase SDK only)

### Data Storage
- Local: UserDefaults (settings), JSON files (guests), Keychain (tokens)
- Cloud: Supabase PostgreSQL (profiles, friendships, matches)
- Offline mode: All gameplay works without internet

### Authentication
- Email/password registration and sign-in
- Google OAuth
- Guest mode (no account required)
- Session stored in Keychain, auto-refresh on launch

### Database Schema
**Tables:**
- `profiles`: id, display_name, nickname (unique), avatar_url, total_wins, total_losses
- `friendships`: id, user_id, friend_id, status
- `matches`: id, game_type, player1_id, player2_id, winner_id, scores, match_data (jsonb), played_at

**Local JSON:**
- `local_players.json`: Guest players with stats

### Error Handling
- Network errors: Retry with backoff
- Auth errors: Redirect to login
- Validation errors: Inline messages
- Sync failures: Notification with manual retry

---

## 7. MVP Scope Summary  

✅ Splash, auth, and onboarding screens  
✅ 7 game modes (301, 501, Halve-It, Knockout, Sudden Death, English Cricket, Killer)  
✅ Pre-game hype screen (boxing match style)  
✅ Guest and connected players  
✅ Google sign-in + email/password  
✅ Score entry with tap/long-press, last-turn edit  
✅ Friends: list, search, add, remove  
✅ Match history with filtering  
✅ Head-to-head stats  
✅ Profile & Settings screen  
✅ Sound effects + toggle  
✅ Offline mode with post-game sync  
✅ Exit game confirmation  
✅ 3-tab navigation (Games, Friends, History)  
✅ Future-ready for ads and enhancements

---

## 8. Future Enhancements (Post-MVP)

- Push notifications (friend requests, game invites)
- Live game sync during gameplay
- Achievements and milestones
- Tournament mode
- Additional game modes
- In-app messaging
- Advanced statistics and visualizations
- Social sharing features