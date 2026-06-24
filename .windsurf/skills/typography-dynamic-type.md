# Typography & Dynamic Type

Reference for how Dart Freak handles font sizing and why Dynamic Type (the iOS system text-size setting) is disabled app-wide.

---

## 1. Decision

Dart Freak **disables Dynamic Type scaling app-wide**. All text renders at the default content size category (`.large`) regardless of the user's iOS text-size setting.

**Why:** User testing showed that enlarged system font sizes broke layouts (clipped/overflowing text, misaligned cards). The app's typography is hand-tuned with fixed point sizes, so honoring Dynamic Type produced worse UX than locking it.

**Tradeoff:** Users who rely on larger system text for accessibility get no scaling benefit inside the app. This was an intentional product decision.

---

## 2. How It Works

The lock is implemented as a **window-level trait override**, not a SwiftUI environment modifier.

`WindowContentSizeLock` in `DanDart/DartFreakApp.swift`:

```swift
struct WindowContentSizeLock: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { TraitLockView() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class TraitLockView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.traitOverrides.preferredContentSizeCategory = .large
        }
    }
}
```

Applied once at the root, on `ContentView` inside `WindowGroup`:

```swift
ContentView()
    .environmentObject(authService)
    .environmentObject(notificationService)
    .environmentObject(voicePermissionManager)
    .background(WindowContentSizeLock())
```

Because it overrides the trait on the **UIWindow**, it covers everything hosted in that window: pushed navigation views, sheets, full-screen covers, popovers, and alerts.

---

## 3. Why NOT `.dynamicTypeSize(.large)`

The first attempt used SwiftUI's `.dynamicTypeSize(.large)` on the root view. **It did not work for sheets.**

- `.dynamicTypeSize` is a SwiftUI **environment** value.
- SwiftUI gives presented content (`.sheet`, `.fullScreenCover`, `.popover`) a **fresh environment** that does NOT inherit from the presenter.
- Result: main navigation screens were locked, but the ~20 sheet presentations (e.g. player selection in `GameSetupView` → `SearchPlayerSheet`) still scaled.

The window-level trait override bypasses this entirely because all presentations share the same window.

---

## 4. Rules for Future Work

- **Do not** rely on `.dynamicTypeSize(...)` for app-wide font locking — it misses presented content.
- **Do not** remove `WindowContentSizeLock` or its `.background(...)` hookup unless intentionally re-enabling Dynamic Type.
- Fixed point sizes (`.font(.system(size: X))`) are unaffected by Dynamic Type and are safe.
- Semantic styles (`.body`, `.headline`, `.title`, `.caption`, etc.) WOULD scale if the lock were removed — many components use them (e.g. `PlayerIdentity`, `ModernSheet`, `MatchCard`, `GameCard`, `TopBar`).
- The lock value is `.large` — iOS's **default** category, not an accessibility size.

---

## 5. Toggling for Before/After Testing

To temporarily re-enable Dynamic Type (e.g. for screenshots), comment out the single hookup line in `DanDart/DartFreakApp.swift`:

```swift
//.background(WindowContentSizeLock())
```

Then clean build + relaunch. Remember to restore it.
