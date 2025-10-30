# Standard Sheet Layout Guide

## Overview
`StandardSheetView` is a reusable wrapper component that provides consistent sheet presentation across the DanDarts app. It follows the Edit Profile layout style with left-aligned title, cancel button, and optional primary action button.

## Location
`/Views/Components/StandardSheetView.swift`

## Design Principles
- **Consistent Header**: Left-aligned title with cancel button (iOS standard)
- **Flexible Content**: ScrollView with standard 16pt horizontal padding
- **Optional Action**: Primary action button at bottom (like "Save Changes")
- **Dark Theme**: Matches app's dark-first design system
- **Accessibility**: Proper navigation structure and button placement

## Usage Examples

### 1. Form Sheet with Primary Action (Edit Profile Style)
```swift
@State private var showEditProfile = false

.sheet(isPresented: $showEditProfile) {
    StandardSheetView(
        title: "Edit Profile",
        primaryActionTitle: "Save Changes",
        primaryActionEnabled: isFormValid,
        onCancel: { showEditProfile = false },
        onPrimaryAction: { saveProfile() }
    ) {
        // Your form content here
        VStack(spacing: 20) {
            TextField("Name", text: $name)
                .textFieldStyle(DartTextFieldStyle())
            
            TextField("Nickname", text: $nickname)
                .textFieldStyle(DartTextFieldStyle())
        }
    }
}
```

### 2. Information Sheet (Instructions Style)
```swift
@State private var showInstructions = false

.sheet(isPresented: $showInstructions) {
    StandardSheetView(
        title: "Instructions",
        showCancelButton: false
    ) {
        // Your content here
        VStack(alignment: .leading, spacing: 16) {
            Text("301")
                .font(.system(size: 48, weight: .bold))
            
            Text("How to Play")
                .font(.system(size: 20, weight: .bold))
            
            Text("Game rules and instructions...")
        }
    }
}
```

### 3. Search/List Sheet (Find Friends Style)
```swift
@State private var showFindFriends = false

.sheet(isPresented: $showFindFriends) {
    StandardSheetView(
        title: "Find Friends",
        cancelButtonTitle: "Back",
        onCancel: { showFindFriends = false }
    ) {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search...", text: $searchQuery)
            }
            .padding(12)
            .background(Color("InputBackground"))
            .cornerRadius(10)
            
            // Results list
            ForEach(searchResults) { result in
                // Result cards
            }
        }
    }
}
```

## Initializer Options

### Option 1: Cancel Only
```swift
StandardSheetView(
    title: String,
    cancelButtonTitle: String = "Cancel",
    onCancel: @escaping () -> Void,
    content: () -> Content
)
```

### Option 2: Cancel + Primary Action
```swift
StandardSheetView(
    title: String,
    cancelButtonTitle: String = "Cancel",
    primaryActionTitle: String,
    primaryActionEnabled: Bool = true,
    onCancel: @escaping () -> Void,
    onPrimaryAction: @escaping () -> Void,
    content: () -> Content
)
```

### Option 3: No Cancel Button (Info Only)
```swift
StandardSheetView(
    title: String,
    showCancelButton: Bool = false,
    content: () -> Content
)
```

## Layout Specifications

### Header
- **Title**: Left-aligned, inline display mode
- **Cancel Button**: Leading toolbar item, AccentPrimary color
- **Height**: Standard iOS navigation bar (44pt)

### Content Area
- **Padding**: 16pt horizontal, 20pt top
- **Spacing**: 16pt between elements
- **Scroll**: Enabled by default with ScrollView
- **Bottom Padding**: 100pt if primary action button present, 20pt otherwise

### Primary Action Button
- **Height**: 50pt
- **Padding**: 16pt horizontal, 16pt vertical
- **Corner Radius**: 12pt
- **Background**: AccentPrimary when enabled, gray when disabled
- **Position**: Fixed at bottom with divider above

## Migration Guide

### Before (Inconsistent)
```swift
.sheet(isPresented: $showSheet) {
    NavigationStack {
        VStack {
            // Content
        }
        .navigationTitle("Title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { }
            }
        }
    }
}
```

### After (Standardized)
```swift
.sheet(isPresented: $showSheet) {
    StandardSheetView(
        title: "Title",
        onCancel: { showSheet = false }
    ) {
        // Content (same as before)
    }
}
```

## Benefits

✅ **Consistency**: All sheets look and behave the same  
✅ **Maintainability**: Update one component to change all sheets  
✅ **Accessibility**: Proper navigation structure built-in  
✅ **Developer Experience**: Less boilerplate code  
✅ **Design System**: Follows app's dark-first theme automatically  

## Files to Update

Apply this standardization to:
1. ✅ `ProfileView.swift` - Edit profile sheet
2. ⚠️ `FriendSearchView.swift` - Find friends sheet
3. ⚠️ `GameInstructionsView.swift` - Instructions sheet (if exists)
4. ⚠️ `AddGuestPlayerView.swift` - Add guest sheet
5. ⚠️ `FriendRequestsView.swift` - Friend requests sheet
6. ⚠️ `BlockedUsersView.swift` - Blocked users sheet

## Notes

- The component automatically handles safe area insets
- ScrollView is included by default for content flexibility
- Primary action button is optional - only shown when provided
- Cancel button text can be customized (e.g., "Back", "Close", "Done")
- For full-screen presentations, continue using NavigationStack directly
