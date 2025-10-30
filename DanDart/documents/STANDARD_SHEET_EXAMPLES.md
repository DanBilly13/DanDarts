# StandardSheetView - Usage Examples

## Overview
The `StandardSheetView` component provides a consistent sheet layout with **flexible dismiss button text** and optional primary action button.

---

## Pattern 1: Form Sheet with "Cancel"
**Use Case**: Edit forms, settings
**Dismiss Button**: "Cancel"

```swift
.sheet(isPresented: $showEditProfile) {
    StandardSheetView(
        title: "Edit Profile",
        dismissButtonTitle: "Cancel",
        primaryActionTitle: "Save Changes",
        primaryActionEnabled: isFormValid,
        onDismiss: { showEditProfile = false },
        onPrimaryAction: { saveProfile() }
    ) {
        // Form fields here
    }
}
```

**Visual Layout**:
```
┌─────────────────────────────┐
│ Cancel                      │
│                             │
│ Edit Profile (LARGE BOLD)   │
│                             │
│ [Form Content]              │
│                             │
│ ┌─────────────────────────┐ │
│ │   Save Changes (BLUE)   │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

---

## Pattern 2: Search/List Sheet with "Back"
**Use Case**: Friend search, player selection
**Dismiss Button**: "Back"

```swift
.sheet(isPresented: $showFindFriends) {
    StandardSheetView(
        title: "Find Friends",
        dismissButtonTitle: "Back",
        onDismiss: { showFindFriends = false }
    ) {
        // Search bar + results
    }
}
```

**Visual Layout**:
```
┌─────────────────────────────┐
│ Back                        │
│                             │
│ Find Friends (LARGE BOLD)   │
│                             │
│ [Search Bar]                │
│ [Results List]              │
│                             │
└─────────────────────────────┘
```

---

## Pattern 3: Info Sheet with "Done"
**Use Case**: Game instructions, help screens
**Dismiss Button**: "Done"

```swift
.sheet(isPresented: $showInstructions) {
    StandardSheetView(
        title: "Instructions",
        dismissButtonTitle: "Done",
        onDismiss: { showInstructions = false }
    ) {
        // Instructions content
    }
}
```

**Visual Layout**:
```
┌─────────────────────────────┐
│ Done                        │
│                             │
│ Instructions (LARGE BOLD)   │
│                             │
│ [Content]                   │
│                             │
└─────────────────────────────┘
```

---

## Pattern 4: Modal with "Close"
**Use Case**: Confirmations, alerts
**Dismiss Button**: "Close"

```swift
.sheet(isPresented: $showConfirmation) {
    StandardSheetView(
        title: "Confirm Action",
        dismissButtonTitle: "Close",
        primaryActionTitle: "Confirm",
        onDismiss: { showConfirmation = false },
        onPrimaryAction: { performAction() }
    ) {
        // Confirmation message
    }
}
```

---

## Pattern 5: Swipe-to-Dismiss Only (No Button)
**Use Case**: Image viewer, full-screen content
**Dismiss Button**: None (swipe down to dismiss)

```swift
.sheet(isPresented: $showImage) {
    StandardSheetView(
        title: "Photo",
        showDismissButton: false
    ) {
        // Image content
    }
}
```

**Visual Layout**:
```
┌─────────────────────────────┐
│                             │
│ Photo (LARGE BOLD)          │
│                             │
│ [Image Content]             │
│                             │
│ (Swipe down to dismiss)     │
└─────────────────────────────┘
```

---

## Common Dismiss Button Options

| Button Text | Use Case |
|-------------|----------|
| **"Cancel"** | Forms, edits (implies discarding changes) |
| **"Back"** | Navigation, search (implies returning to previous) |
| **"Done"** | Info screens, completed actions |
| **"Close"** | Modals, overlays |
| **None** | Full-screen content (swipe-to-dismiss) |

---

## Component Parameters

### All Initializers Support:
- `title: String` - Large bold title at top
- `dismissButtonTitle: String` - Text for top-left button (default: "Cancel")
- `onDismiss: () -> Void` - Action when dismiss button tapped

### Optional Parameters:
- `primaryActionTitle: String?` - Bottom button text (e.g., "Save Changes")
- `primaryActionEnabled: Bool` - Enable/disable bottom button (default: true)
- `onPrimaryAction: (() -> Void)?` - Action when bottom button tapped
- `showDismissButton: Bool` - Show/hide top-left button (default: true)

---

## Design Specifications

### Title
- **Font**: System, Large, Bold
- **Color**: TextPrimary (white)
- **Position**: Top, left-aligned
- **Display Mode**: `.large` (iOS standard)

### Dismiss Button
- **Position**: Top-left toolbar
- **Color**: AccentPrimary (blue)
- **Font**: System, 17pt
- **Text**: Flexible ("Cancel", "Back", "Done", "Close", etc.)

### Primary Action Button
- **Position**: Fixed at bottom
- **Height**: 50pt
- **Corner Radius**: 12pt
- **Background**: AccentPrimary when enabled, gray when disabled
- **Text Color**: White
- **Font**: System, 17pt, Semibold

### Content Area
- **Padding**: 16pt horizontal, 20pt top
- **Spacing**: 16pt between elements
- **Scroll**: Enabled by default
- **Background**: BackgroundPrimary (dark)

---

## Migration from Old Pattern

### Before (Manual Setup):
```swift
NavigationStack {
    ScrollView {
        VStack {
            // Content
        }
        .padding()
    }
    .navigationTitle("Title")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
        }
    }
}
```

### After (StandardSheetView):
```swift
StandardSheetView(
    title: "Title",
    dismissButtonTitle: "Cancel",
    onDismiss: { dismiss() }
) {
    // Content (same as before)
}
```

**Result**: 70% less boilerplate code!
