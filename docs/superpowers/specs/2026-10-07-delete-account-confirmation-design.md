# Delete Account: type DELETE to confirm

## Why

On 2026-10-04 a real account was deleted by the app's Delete Account function, and nobody could say who had triggered it. Today one confirmation alert and one tap is all it takes. This adds a deliberate typing step so a stray tap, or a signed-in app handed to someone else, can't wipe an account.

## Behaviour

- Tapping **Delete Account** opens the existing "Delete Account?" alert, now with a text field ("Type DELETE to confirm").
- The red **Delete Account** button stays disabled until the field reads DELETE. The check ignores capital letters and leading or trailing spaces.
- Cancelling empties the field, so it starts empty every time.
- Everything after confirmation is unchanged: the same `delete-account` call, the same error alert, the same sign-out.

## Code

- `DeleteAccountConfirmation.isConfirmed(_:)` (pure, unit tested with Swift Testing).
- `SettingsView.swift`: the delete alert gains the field and the disabled check.

## Not in this change

A second sign-in before deleting, and an audit record of deletions in the server function. Both were considered and left out by choice; the `delete-account` function is shared with Android and untouched here. The Android app gets the same confirmation in its own PR.
