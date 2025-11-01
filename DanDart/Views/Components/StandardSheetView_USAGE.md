# StandardSheetView Usage Guide

## Overview
`StandardSheetView` is a reusable SwiftUI component that provides a consistent sheet layout across the app. It handles header, title, content area, and optional action buttons with proper styling and padding.

## Basic Usage

### 1. Simple Sheet with Dismiss Button

```swift
StandardSheetView(
    title: "Edit Profile",
    dismissButtonTitle: "Cancel",  // Default: "Cancel"
    onDismiss: { dismiss() }
) {
    // Your content here
    VStack(spacing: 20) {
        Text("Content goes here")
    }
}
```

### 2. Sheet with Primary Action Button

```swift
StandardSheetView(
    title: "Create Player",
    dismissButtonTitle: "Cancel",
    primaryActionTitle: "Save",
    primaryActionEnabled: isFormValid,
    onDismiss: { dismiss() },
    onPrimaryAction: { savePlayer() }
) {
    // Your form content
    VStack(spacing: 20) {
        TextField("Name", text: $name)
    }
}
```

### 3. Sheet Without Dismiss Button (Swipe-to-dismiss only)

```swift
StandardSheetView(
    title: "Instructions",
    showDismissButton: false
) {
    // Content
    Text("Game instructions...")
}
```

## Important: useScrollView Parameter

### When to use `useScrollView: true` (Default)
- Content is static and fits in a ScrollView
- You want automatic padding and scrolling
- Most common use case

```swift
StandardSheetView(
    title: "Settings",
    dismissButtonTitle: "Done",
    useScrollView: true,  // Default, can be omitted
    onDismiss: { dismiss() }
) {
    VStack(spacing: 20) {
        Toggle("Enable notifications", isOn: $notifications)
        Toggle("Dark mode", isOn: $darkMode)
    }
}
```

### When to use `useScrollView: false`
- You need custom scrolling behavior
- You have a search bar or fixed header
- You manage your own ScrollView

```swift
StandardSheetView(
    title: "Find Friends",
    dismissButtonTitle: "Back",
    useScrollView: false,  // ⚠️ IMPORTANT
    onDismiss: { dismiss() }
) {
    VStack(spacing: 0) {
        // Fixed search bar at top
        SearchBar(text: $query)
        
        // Custom ScrollView for results
        ScrollView {
            ForEach(results) { result in
                ResultRow(result: result)
            }
        }
    }
}
```

## ⚠️ Critical: Padding Behavior

### With `useScrollView: true` (Default)
- Content automatically gets `.padding(.horizontal, 16)`
- Content automatically gets `.padding(.top, 4)`
- Content wrapped in VStack with 16pt spacing
- **You don't need to add padding yourself**

### With `useScrollView: false`
- Content still gets `.padding(.horizontal, 16)` automatically (as of fix)
- Content still gets `.padding(.top, 4)` automatically
- **You don't need to add padding yourself**
- But you manage your own scrolling

## Common Patterns

### Pattern 1: Edit Profile Style
```swift
StandardSheetView(
    title: "Edit Profile",
    dismissButtonTitle: "Cancel",
    primaryActionTitle: "Save Changes",
    primaryActionEnabled: hasChanges,
    onDismiss: { dismiss() },
    onPrimaryAction: { saveChanges() }
) {
    VStack(spacing: 20) {
        // Avatar selection
        AvatarPicker(selection: $avatar)
        
        // Form fields
        TextField("Display Name", text: $displayName)
        TextField("Nickname", text: $nickname)
    }
}
```

### Pattern 2: Search with Custom Scrolling
```swift
StandardSheetView(
    title: "Find Friends",
    dismissButtonTitle: "Back",
    useScrollView: false,
    onDismiss: { dismiss() }
) {
    VStack(spacing: 0) {
        // Fixed search bar
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search...", text: $query)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("InputBackground"))
        .cornerRadius(12)
        .padding(.bottom, 16)
        
        // Scrollable results
        if results.isEmpty {
            EmptyStateView()
        } else {
            ScrollView {
                ForEach(results) { result in
                    ResultCard(result: result)
                }
            }
        }
    }
}
```

### Pattern 3: Instructions/Info Style
```swift
StandardSheetView(
    title: "How to Play",
    showDismissButton: false  // Swipe-to-dismiss only
) {
    VStack(alignment: .leading, spacing: 16) {
        Text("301")
            .font(.largeTitle)
            .bold()
        
        Text("A classic countdown game")
            .foregroundColor(.secondary)
        
        Text("Rules:")
            .font(.headline)
        
        Text("Each player starts with 301 points...")
    }
}
```

## Styling Reference

### Automatic Styling Provided
- **Header:** 16pt horizontal padding, 12pt vertical padding
- **Title:** 34pt bold, 16pt horizontal padding, 8pt top / 16pt bottom padding
- **Content:** 16pt horizontal padding, 4pt top padding
- **Primary Button:** Full width, 50pt height, 12pt corner radius, 16pt padding

### Colors Used
- Background: `Color("BackgroundPrimary")`
- Title: `Color("TextPrimary")`
- Dismiss button: `Color("AccentPrimary")`
- Primary action: `Color("AccentPrimary")` (enabled), gray (disabled)

## Dismiss Button Text Options

The `dismissButtonTitle` parameter accepts any string:
- "Cancel" (default)
- "Back"
- "Close"
- "Done"
- Any custom text

## Best Practices

### ✅ DO
- Use `useScrollView: true` for most cases
- Let the sheet handle padding automatically
- Use descriptive dismiss button text ("Back", "Done", etc.)
- Disable primary action button when form is invalid
- Keep content spacing consistent (16pt or 20pt)

### ❌ DON'T
- Don't add your own `.padding(.horizontal, 16)` to root content
- Don't use `useScrollView: false` unless you need custom scrolling
- Don't nest multiple ScrollViews (causes scroll conflicts)
- Don't forget to disable primary action when form is invalid

## Troubleshooting

### Issue: Content is too wide / ignoring padding
**Solution:** This should be fixed automatically. If you still see issues, ensure you're not adding extra padding yourself.

### Issue: Content not scrolling
**Solution:** Make sure `useScrollView: true` (default) or manage your own ScrollView with `useScrollView: false`.

### Issue: Primary action button not showing
**Solution:** Ensure you're using the correct initializer with `primaryActionTitle` and `onPrimaryAction` parameters.

### Issue: Can't dismiss sheet
**Solution:** Make sure you're calling the `onDismiss` closure, which should typically call `dismiss()` from `@Environment(\.dismiss)`.

## Examples in Codebase

- **Edit Profile:** `EditProfileView.swift`
- **Find Friends:** `FriendSearchView.swift` (uses `useScrollView: false`)
- **Match Summary:** `MatchSummarySheetView.swift`
- **Friend Requests:** `FriendRequestsView.swift`

## Migration from Old Sheets

If you have an existing custom sheet:

**Before:**
```swift
NavigationView {
    ScrollView {
        VStack {
            // content
        }
        .padding()
    }
    .navigationTitle("Title")
    .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") { dismiss() }
        }
    }
}
```

**After:**
```swift
StandardSheetView(
    title: "Title",
    dismissButtonTitle: "Cancel",
    onDismiss: { dismiss() }
) {
    // content (padding handled automatically)
}
```

## Version History

- **v1.0:** Initial implementation with ScrollView support
- **v1.1:** Added `useScrollView: false` support
- **v1.2:** Fixed padding issue for `useScrollView: false` case (Nov 1, 2025)
