# AI Avatar Generation – v1 Flow

This document describes the **initial, simplified flow** for adding an Apple Intelligence–powered avatar generator to the **Edit Profile** screen.

The focus of v1 is to ship a reliable, predictable feature that integrates cleanly with the existing avatar carousel.

---

## Overview

**User intent**

“I want a new avatar. Show me one. If I like it, I’ll use it. If not, I’ll try again.”

**High-level behavior**

- Apple Intelligence generates **one avatar at a time**
- The avatar is previewed in a dedicated sheet
- The user explicitly confirms before the avatar is added to their profile

---

## Entry Point

**Location**

Edit Profile → Avatar row at the top of the sheet

**Controls**

```
[ Camera ] [ ✨ Apple Intelligence ] [ avatar ] [ avatar ] …
```

- 📷 Camera → existing photo picker flow
- ✨ Apple Intelligence → AI avatar generation flow

The AI option is presented as an additional avatar source, not a replacement.

---

## Step-by-Step Flow

### 1. Tap Apple Intelligence Icon

**Action**
- User taps the ✨ icon

**Result**
- A modal sheet opens

---

### 2. Style Selection (Sheet – Initial State)

**Title**
Generate Avatar

**Content**
```
Choose a style

[ 🎯 Animated Mascot – Human ]
[ 🎨 Animated Mascot – Feminine ]
[ ⚡ Animated Mascot – Animal ]

(Uses Apple Intelligence)
```

**Rules**
- No text input
- Single-tap selection
- Sheet remains open after selection

---

### 3. Generation State (Loading)

After a style is selected:

- Style buttons are hidden or disabled
- Loading indicator / shimmer is shown

Example:
```
Generating avatar…

[ ○ ○ ○ ]
```

No avatar is committed at this stage.

---

### 4. Preview Generated Avatar

When generation completes:

```
[ Large avatar preview ]

[ Regenerate ]   [ Use This Avatar ]
```

**Notes**
- Preview is larger than carousel avatars
- One avatar per generation (v1)

---

### 5a. Regenerate

- Generates a new avatar using the same style
- Replaces the preview
- Remains on the sheet

---

### 5b. Use This Avatar

When tapped:

1. Sheet dismisses
2. Avatar is added to the avatar carousel
3. Avatar is centered and selected

---

## Data & Storage

### Temporary Storage (Before Save)

- Generated avatars are temporary until **Save Changes**
- Temporary storage should be:
  - In-memory (preferred), or
  - Temporary file in cache / temp directory

If Edit Profile is dismissed without saving:
- All generated avatars are discarded

---

### Persistent Storage (After Save)

- Selected avatar is treated like any other profile image
- Recommended approach:
  - Upload image to Supabase Storage
  - Store resulting `avatar_url` on the user profile

Once saved, the stored image is the source of truth.

---

## Prompt Templates (v1)

All prompts target **Animation** style.

### Animated Mascot – Human

```
A fun, animated-style mascot avatar of a human darts player.
Bright colors, soft lighting, rounded shapes, expressive face,
clean background, friendly and playful mood.
```

---

### Animated Mascot – Feminine

```
A fun, animated-style mascot avatar with a feminine look.
Expressive eyes, stylized hair, soft shading, bright colors,
rounded cartoon proportions, friendly and confident personality.
```

---

### Animated Mascot – Animal

```
A playful animated animal mascot avatar inspired by darts and games.
Cute creature, bold shapes, vibrant colors, expressive eyes,
simple background, fun and energetic cartoon style.
```

---

## Availability & Gating

The Apple Intelligence avatar option should only be shown when:

- Device supports Apple Intelligence
- Required iOS version is available
- Apple Intelligence is enabled by the user

### When Not Available

Possible reasons:
- Unsupported device or OS
- Apple Intelligence disabled
- Required system resources unavailable

### Fallback Behavior

- Hide the ✨ button, or
- Show disabled state with helper text:
  “Not available on this device”

Users must always have access to:
- Camera / photo picker
- Existing avatars

---

## Privacy & Permissions

- Avatar generation uses **on-device Apple Intelligence**
- No camera or microphone permissions are required
- Camera icon remains a separate, permission-based flow

### Network Usage

- If generation is fully on-device, no network calls are required
- Any future network usage must be explicitly documented

This clarity supports App Store review, debugging, and user trust.

---

## Error & Failure Handling

### Generation Failure
- Show inline error in the sheet
- Provide “Try again” action

### Timeout / Rate Limiting
- Show non-blocking error
- Allow retry

### Sheet Dismissed Mid-Generation
- Cancel in-flight generation task
- Discard partial results

No avatar is committed without explicit confirmation.

---

## UX & Interaction Guidelines

### Haptics
- Light haptic on style selection
- Medium haptic on “Use This Avatar”
- Warning haptic on failure

### Loading & Accessibility
- Use accent spinner
- Respect Reduce Motion
- Avoid blocking animations

---

## Design Principles

- Generation ≠ selection
- Preview before commitment
- Explicit confirmation
- Minimal cognitive load
- No disruption to existing UI patterns

---

## Summary

This v1 flow is designed to be:
- Simple
- Predictable
- Apple-like
- Easy to extend later

It provides a solid foundation for future AI avatar enhancements.
