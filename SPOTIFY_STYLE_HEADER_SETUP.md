# Spotify-Style Header Implementation

## Overview
Implemented a Spotify-inspired full-width cover image header for the GameSetupView with transparent navigation overlay.

## Design Features

### 1. Full-Width Cover Image
- **Height:** 280pt
- **Aspect Ratio:** Fill (covers full width, crops height if needed)
- **Image Path:** `game-cover/{game.title}` (e.g., "game-cover/301")
- **Fallback:** Gradient using AccentPrimary if image not found

### 2. Gradient Overlay
- **Purpose:** Ensures text readability over any image
- **Colors:** Black opacity 0.0 (top) → 0.7 (bottom)
- **Effect:** Creates a darkened area at bottom for title

### 3. Game Title
- **Font:** 48pt, Bold, Rounded
- **Color:** White
- **Position:** Bottom-left of header
- **Padding:** 20pt left, 24pt bottom
- **Shadow:** Black 30% opacity, 10pt radius

### 4. Transparent Navigation Bar
- **Position:** Overlaid on top of header
- **Back Button:** 
  - Circular background with black 30% opacity
  - White chevron icon
  - 12pt padding
  - Subtle shadow for depth
- **Behavior:** Floats above content, doesn't push it down

## File Modified

### GameSetupView.swift
**Changes:**
1. Replaced fixed top bar with ZStack layout
2. Added ScrollView with header image section
3. Added gradient overlay for text readability
4. Positioned game title over image
5. Added transparent navigation overlay
6. Used `.edgesIgnoringSafeArea(.top)` to extend to screen edge

## Image Asset Setup

### Required Assets
Place cover images in Xcode Asset Catalog:
- **Folder:** `game-cover`
- **Format:** PNG or JPG
- **Naming:** Match game title exactly
  - `game-cover/301`
  - `game-cover/501`
  - `game-cover/Halve-It`
  - `game-cover/Knockout`
  - `game-cover/Sudden Death`
  - `game-cover/Cricket`
  - `game-cover/Killer`

### Recommended Image Specs
- **Dimensions:** 1170 x 800px (or similar 3:2 ratio)
- **Resolution:** @2x and @3x for retina displays
- **Format:** PNG for transparency support, JPG for photos
- **File Size:** < 500KB per image

## Layout Structure

```
ZStack (alignment: .top)
├── ScrollView
│   └── VStack
│       ├── Hero Header (280pt)
│       │   ├── Cover Image (full width)
│       │   ├── Gradient Overlay
│       │   └── Game Title (bottom-left)
│       └── Content
│           ├── Match Format Section
│           ├── Players Section
│           ├── Start Game Button
│           └── Instructions Section
└── Transparent Nav Bar Overlay
    └── Back Button (top-left)
```

## Key SwiftUI Techniques

### 1. ZStack with Alignment
```swift
ZStack(alignment: .top) {
    ScrollView { ... }
    VStack { /* Nav overlay */ }
}
```

### 2. Full-Width Image
```swift
Image(uiImage: coverImage)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(height: 280)
    .clipped()
```

### 3. Gradient Overlay
```swift
LinearGradient(
    colors: [
        Color.black.opacity(0.0),
        Color.black.opacity(0.7)
    ],
    startPoint: .top,
    endPoint: .bottom
)
```

### 4. Floating Navigation
```swift
VStack {
    HStack {
        Button { ... }
            .background(Color.black.opacity(0.3))
            .clipShape(Circle())
        Spacer()
    }
    Spacer()
}
```

## Benefits

1. **Visual Impact** - Large hero image creates strong first impression
2. **Brand Identity** - Each game has unique visual identity
3. **Modern UX** - Follows patterns from popular apps (Spotify, Apple Music)
4. **Flexible** - Works with any image, has fallback gradient
5. **Readable** - Gradient ensures text is always legible
6. **Clean** - Transparent nav doesn't clutter the design

## Customization Options

### Adjust Header Height
Change `frame(height: 280)` to desired height (e.g., 240, 320)

### Modify Gradient Intensity
Adjust opacity values:
```swift
Color.black.opacity(0.0) // Top (0.0 = transparent)
Color.black.opacity(0.7) // Bottom (0.7 = 70% dark)
```

### Change Title Size/Position
```swift
.font(.system(size: 48, weight: .bold, design: .rounded))
.padding(.leading, 20)
.padding(.bottom, 24)
```

### Customize Back Button
```swift
.background(Color.black.opacity(0.3)) // Background opacity
.padding(12) // Button size
```

## Future Enhancements

- [ ] Parallax scrolling effect (image moves slower than content)
- [ ] Blur effect on scroll (header blurs as you scroll down)
- [ ] Animated title fade-in
- [ ] Dynamic color extraction from image for theme
- [ ] Video backgrounds for premium feel
- [ ] Seasonal/event-specific covers

## Testing Checklist

- [ ] Test with all game types (301, 501, etc.)
- [ ] Test with missing images (fallback gradient)
- [ ] Test on different screen sizes (iPhone SE, Pro Max)
- [ ] Test in light/dark mode
- [ ] Test scroll behavior
- [ ] Test back button functionality
- [ ] Test with long game titles
- [ ] Test with various image aspect ratios

## Notes

- Images are loaded using `UIImage(named:)` for Asset Catalog support
- Fallback gradient uses app's AccentPrimary color
- Navigation bar is completely transparent, no background
- Back button has semi-transparent background for visibility
- Layout automatically adjusts for safe area
- Works seamlessly with existing game setup flow
