# Sheet Migration Example

## Before & After Comparison

### Example 1: Edit Profile Sheet

#### BEFORE (Current Implementation)
```swift
// In ProfileView.swift
.sheet(isPresented: $showEditProfile) {
    NavigationStack {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Picture Section
                    VStack(spacing: 12) {
                        Text("Profile Picture")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Avatar selection...
                    }
                    
                    // Name field...
                    // Nickname field...
                    // Email field...
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            
            // Save button at bottom
            VStack(spacing: 0) {
                Divider()
                Button("Save Changes") {
                    saveProfile()
                }
                .padding(16)
            }
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showEditProfile = false
                }
                .foregroundColor(Color("AccentPrimary"))
            }
        }
    }
}
```

#### AFTER (Using StandardSheetView)
```swift
// In ProfileView.swift
.sheet(isPresented: $showEditProfile) {
    StandardSheetView(
        title: "Edit Profile",
        primaryActionTitle: "Save Changes",
        primaryActionEnabled: isFormValid,
        onCancel: { showEditProfile = false },
        onPrimaryAction: { saveProfile() }
    ) {
        // Profile Picture Section
        VStack(spacing: 12) {
            Text("Profile Picture")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Avatar selection...
        }
        
        // Name field...
        // Nickname field...
        // Email field...
    }
}
```

**Lines of Code**: 45 → 20 (56% reduction!)

---

### Example 2: Find Friends Sheet

#### BEFORE
```swift
.sheet(isPresented: $showFindFriends) {
    NavigationStack {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search...", text: $searchQuery)
            }
            .padding()
            
            // Results...
        }
        .navigationTitle("Find Friends")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    showFindFriends = false
                }
            }
        }
    }
}
```

#### AFTER
```swift
.sheet(isPresented: $showFindFriends) {
    StandardSheetView(
        title: "Find Friends",
        cancelButtonTitle: "Back",
        onCancel: { showFindFriends = false }
    ) {
        // Search bar
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search...", text: $searchQuery)
        }
        .padding(12)
        .background(Color("InputBackground"))
        .cornerRadius(10)
        
        // Results...
    }
}
```

---

### Example 3: Instructions Sheet (Read-Only)

#### BEFORE
```swift
.sheet(isPresented: $showInstructions) {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("301")
                    .font(.system(size: 48, weight: .bold))
                
                Text("How to Play")
                    .font(.system(size: 20, weight: .bold))
                
                // Instructions content...
            }
            .padding()
        }
        .navigationTitle("Instructions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    showInstructions = false
                }
            }
        }
    }
}
```

#### AFTER
```swift
.sheet(isPresented: $showInstructions) {
    StandardSheetView(
        title: "Instructions",
        showCancelButton: false  // No cancel needed for info sheets
    ) {
        VStack(alignment: .leading, spacing: 16) {
            Text("301")
                .font(.system(size: 48, weight: .bold))
            
            Text("How to Play")
                .font(.system(size: 20, weight: .bold))
            
            // Instructions content...
        }
    }
}
```

**Note**: User dismisses by swiping down (standard iOS sheet behavior)

---

## Migration Checklist

For each sheet in your app:

1. ✅ Identify the sheet type:
   - Form with action button? → Use `primaryActionTitle`
   - Search/list? → Use `cancelButtonTitle: "Back"`
   - Info only? → Use `showCancelButton: false`

2. ✅ Replace NavigationStack wrapper with StandardSheetView

3. ✅ Move content inside the content closure

4. ✅ Remove manual padding (StandardSheetView handles it)

5. ✅ Remove toolbar and navigation title code

6. ✅ Test sheet presentation and dismissal

## Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Code Lines** | ~40-50 per sheet | ~15-20 per sheet |
| **Consistency** | Varies by developer | Always same |
| **Maintainability** | Update each sheet | Update one component |
| **Bugs** | Padding/spacing issues | Standardized |
| **Onboarding** | Learn each pattern | Learn one pattern |

## Next Steps

1. ✅ Review StandardSheetView.swift
2. ✅ Test with one sheet (e.g., Edit Profile)
3. ⚠️ Migrate remaining sheets one by one
4. ⚠️ Update documentation as needed
5. ⚠️ Remove old sheet boilerplate code
