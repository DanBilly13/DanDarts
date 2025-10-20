# UX Improvements: Profile Setup Consistency

## Issues Fixed
1. **Avatar selection inconsistency** - ProfileSetupView and AddGuestPlayerView had different avatar pickers
2. **Removed bio field** - Not needed for MVP
3. **Removed duplicate nickname/handle input** - Already collected during signup

## Changes Made

### ProfileSetupView.swift - Simplified & Consistent

**Before:**
- Asked for handle (duplicate of nickname from signup)
- Asked for bio (optional, not needed)
- Used SF Symbols only for avatars (8 options)
- Different avatar picker UI than AddGuestPlayerView

**After:**
- Only asks for avatar selection
- Uses same avatar picker as AddGuestPlayerView
- 4 asset avatars + 4 SF Symbol avatars (8 total)
- Consistent UI/UX across the app

### Key Changes:

**1. Removed Handle Field**
- Nickname is already collected during signup
- No need to ask again in profile setup
- Reduces friction in onboarding flow

**2. Removed Bio Field**
- Not essential for MVP
- Can be added later if needed
- Simplifies profile setup

**3. Unified Avatar Picker**
- Now uses same `AvatarOption` and `AvatarOptionView` components
- Same 8 avatars as AddGuestPlayerView:
  - `avatar1`, `avatar2`, `avatar3`, `avatar4` (assets)
  - `person.circle.fill`, `person.crop.circle.fill`, `figure.wave.circle.fill`, `person.2.circle.fill` (SF Symbols)
- Consistent size (70pt) and styling
- Same selection animation and visual feedback

**4. Updated Header Text**
- Changed from "Complete Your Profile" to "Choose Your Avatar"
- More focused and clear about what user needs to do
- Subtitle: "Pick an avatar to personalize your profile"

## User Flow Comparison

### Before:
1. Sign up → Enter email, password, display name, **nickname**
2. Profile setup → Enter **handle** (duplicate!), bio, choose avatar
3. Main app

### After:
1. Sign up → Enter email, password, display name, **nickname**
2. Profile setup → Choose avatar only
3. Main app

## Benefits

1. **Reduced Friction** - Fewer fields to fill = faster onboarding
2. **Consistency** - Same avatar picker everywhere
3. **No Duplication** - Don't ask for nickname twice
4. **Clearer Purpose** - Profile setup is now just about avatar selection
5. **Better UX** - Users can skip if they want (default avatar assigned)

## Technical Details

**Shared Components:**
- `AvatarType` enum (asset/symbol)
- `AvatarOption` struct
- `AvatarOptionView` component

These are now defined in both:
- `AddGuestPlayerView.swift`
- `ProfileSetupView.swift`

**Future Consideration:**
Could extract these to a shared file (e.g., `AvatarComponents.swift`) to avoid duplication, but for now they're small enough to keep inline.

## Testing Checklist
- [ ] Sign up with email → Profile setup shows avatar picker only
- [ ] Avatar selection works (assets and SF Symbols)
- [ ] Complete setup → Avatar saved to profile
- [ ] Skip setup → Default avatar assigned
- [ ] Add guest player → Same avatar picker
- [ ] Avatar selection consistent across both views

## Files Modified
- **ProfileSetupView.swift** - Simplified to avatar selection only, added shared components
