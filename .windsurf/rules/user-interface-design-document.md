---
trigger: manual
---

# DanDarts — UI Design Document

## Overview
DanDarts uses a dark-first, energetic design system built on native iOS SwiftUI components. Design inspiration: Apple Fitness for structure, Apple Calculator for scoring interactions.

---

## Layout Structure

### Screen Hierarchy
- **Top Bar:** 44pt height, app logo (left) + profile avatar (right, 32pt circle)
- **Content Area:** Scrollable with safe area insets
- **Bottom Tab Bar:** 49pt height, 3 tabs with SF Symbol icons

### Grid System
- 16pt standard margin from edges
- 12pt spacing between cards
- 8pt internal padding

### Navigation
- **Tab Bar:** Primary (Games, Friends, History)
- **Modal:** Game setup, profile/settings
- **Push:** Game flow (details → hype → gameplay)

---

## Core Components

### Top Bar
- Dark background
- Left: "DanDarts" SF Pro Display Semibold, 20pt
- Right: 32pt avatar circle with 2pt accent border when online
- Hidden during active gameplay

### Bottom Tab Bar
- 3 tabs: Games (`target`), Friends (`person.2.fill`), History (`chart.bar.fill`)
- Selected: Accent color with scale animation
- Unselected: Gray 60% opacity

### Game Cards
- Horizontal carousel, 90% width, 200pt height
- Dark gradient background, 16pt radius
- Game name: SF Pro Display Bold, 28pt
- Tagline: SF Pro Text Regular, 16pt, 70% opacity
- "Play" button: Bottom right pill, accent fill
- Shadow: 4pt y, 12pt blur, black 30%

### Player Cards
- 80pt height, dark background, 1pt border (white 20%)
- 12pt radius
- Layout: 48pt avatar (left) + name/nickname (center) + stats (right)
- Active state: Border changes to accent color

### Avatar
- Sizes: 32pt (top bar), 48pt (cards), 80pt (profiles), 120pt (hype screen)
- 2pt border, white 30% (accent when active)
- Placeholder: `person.circle.fill` if no image

### Buttons
**Primary:**
- Pill shaped, 50pt height
- Accent gradient background
- SF Pro Text Semibold, 17pt, white
- Tap: Scale 0.95 + haptic

**Secondary:**
- White 15% background, 1pt border
- White text

**Scoring (Gameplay):**
- 64pt circular (Calculator-inspired)
- Dark gray background (system gray5)
- SF Pro Display Medium, 24pt
- Long-press: Contextual menu for Double/Triple
- Active: Accent fill + scale

### Text Fields
- 44pt height, 10pt radius
- White 10% background, 1pt border (20% opacity)
- Focus: Border changes to accent
- Placeholder: White 40% opacity

### Lists
**Grouped (Settings, Friends):**
- Dark sections, rounded corners
- 44-60pt rows
- Hairline dividers (white 15%)

**Plain (History):**
- Cards with 12pt spacing

---

## Interaction Patterns

### Scoring Workflow
1. Tap number → brief scale + accent color
2. Score updates immediately
3. Long-press → Double/Triple menu
4. "Save Score" → turn slides/fades to next player
5. "Undo" appears for 5 seconds

### Gestures
- Swipe back (standard iOS)
- Pull to refresh (History tab)
- Swipe left on friend (reveals "Remove")
- Minimum 44x44pt tap targets

### Animations
**Standard:** iOS default transitions

**Custom:**
- Hype screen: Avatars slide in (0.6s spring, damping 0.7)
- "VS" fade/scale (0.4s delay)
- Turn switch: Scale down/up (0.3s ease-in-out)
- Winner: Confetti particles (2s)
- Score tap: Scale 0.92 (0.1s)

### Haptic Feedback
- Light: Score tap
- Medium: Save score, turn change
- Heavy: Game start/end
- Success: Checkout/win
- Warning: Invalid input

### Loading States
- Activity indicator (accent color)
- Skeleton screens (search, history)
- Pull-to-refresh control

---

## Color Scheme

### Primary
- **Background:** `#0A0A0F` (black with blue tint)
- **Surface:** `#1C1C1E` (iOS gray6 dark)
- **Text Primary:** `#FFFFFF`
- **Text Secondary:** `#FFFFFFB3` (70% opacity)

### Accent
- **Interactive Primary:** `#0A84FF` (iOS system blue or custom)
- **Interactive Secondary:** `#FF9500` (iOS system orange)
- **Success:** `#30D158` (iOS system green)
- **Error:** `#FF453A` (iOS system red)
- **Warning:** `#FFD60A` (iOS system yellow)

### Usage
- Accent primary: CTAs, selected states, active player
- Accent secondary: Celebrations, winner highlights
- All colors support accessibility contrast ratios

### Depth
- Cards: Subtle shadow
- Modals: Larger shadow
- Shadows: Black 20-40%, blur 8-16pt

---

## Typography

### Font Family
- SF Pro Display: Large text (20pt+)
- SF Pro Text: Body and UI (<20pt)

### Scale
- **Title Large:** Bold 34pt
- **Title Medium:** Semibold 28pt
- **Title Small:** Semibold 22pt
- **Headline:** Semibold 17pt
- **Body:** Regular 17pt
- **Callout:** Regular 16pt
- **Caption:** Regular 12pt

### Support
- Dynamic Type enabled
- Test at "Extra Extra Large" minimum
- Readable content guide respected

---

## Accessibility

### Visual
- Contrast: 7:1 text, 4.5:1 interactive (AAA)
- Never rely on color alone
- Dark mode default, light mode available

### Motor
- 44x44pt minimum touch targets
- 8pt spacing between interactive elements
- Button alternatives for all swipes

### Cognitive
- Clear descriptive labels
- Confirmation for destructive actions
- Progress indicators shown

### VoiceOver
- Meaningful alt text
- Buttons announce action
- Logical navigation order
- Game state announced clearly

### Settings Support
- Reduce Motion: Fade instead of animations
- Sound toggle: Visual alternatives provided
- Dynamic Type: All text scales

### Localization
- RTL layout support
- Locale-aware dates/numbers
- All strings localized

---

## Component States

### Interactive Elements
- **Default:** Base styling
- **Focused:** Subtle glow/border
- **Pressed:** Scale 0.95 + haptic
- **Disabled:** 40% opacity
- **Loading:** Activity indicator

### Form Validation
- **Valid:** Accent checkmark
- **Invalid:** Error color + message
- **In Progress:** No validation until blur

### Network
- **Online:** Accent border on avatar
- **Offline:** No border
- **Syncing:** Activity indicator
- **Failed:** Warning + retry

---

## Platform Considerations

### iOS Mobile (Primary)
- Target: iPhone 12 Pro+ (6.1"-6.7")
- iOS 16 minimum
- Portrait primary, landscape disabled in gameplay
- Safe area insets respected

### Future
- iPad: Multi-column layouts, sidebars
- Web: PWA with responsive breakpoints
- macOS: Catalyst with keyboard shortcuts

---

## Design System Notes

- Native iOS components prioritized
- 16pt/12pt/8pt spacing rhythm
- Centralized styling for easy theming
- Optimized images and lazy loading
- Color palette swappable via design tokens