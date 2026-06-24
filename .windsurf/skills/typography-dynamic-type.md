# Typography & Dynamic Type

Reference for how Dart Freak handles font sizing and Dynamic Type (the iOS system text-size setting).

---

## 1. Current State

Dart Freak **honors Dynamic Type app-wide**. The user's iOS text-size setting now scales text throughout the app, including sheets, full-screen covers, popovers, and alerts.

---

## 2. Historical Context

A previous implementation disabled Dynamic Type by overriding the window's `preferredContentSizeCategory` to `.large` via a `UIViewRepresentable` called `WindowContentSizeLock`. It was added because an earlier attempt using `.dynamicTypeSize(.large)` on the root view did not propagate into SwiftUI presented content (`.sheet`, `.fullScreenCover`, `.popover`).

That lock has been removed. The app now relies on the standard system behavior, and any layout issues caused by enlarged text should be addressed by fixing the affected layouts rather than disabling accessibility.

---

## 3. Rules for Future Work

- **Do not** reintroduce a global lock on `preferredContentSizeCategory` unless there is a new product decision to disable Dynamic Type.
- **Do not** use `.dynamicTypeSize(...)` to suppress scaling; it does not propagate into presented content.
- Fixed point sizes (`.font(.system(size: X))`) are unaffected by Dynamic Type and are safe.
- Semantic styles (`.body`, `.headline`, `.title`, `.caption`, etc.) **will** scale with Dynamic Type. Many components use them (e.g. `PlayerIdentity`, `ModernSheet`, `MatchCard`, `GameCard`, `TopBar`).
- When laying out text, use scalable containers, `minimumScaleFactor`, and flexible frames where appropriate so larger sizes do not clip or overflow.

---

## 4. Testing

- Use the Accessibility Inspector or iOS Settings → Display & Text Size → Larger Text to verify scaling.
- Check sheets, full-screen covers, popovers, and alerts explicitly, as these were previously unaffected by `.dynamicTypeSize`.
