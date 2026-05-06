# Voice Permission Onboarding Fallback

## Context

A regression occurred after permission prompts were moved out of `RemoteGamesTab` and into the new signup permissions onboarding screen.

New users were expected to choose notification and voice intent in `PermissionsOnboardingView`, then request microphone permission from that stable onboarding context.

Existing users, however, may never pass through the new onboarding screen. If their microphone permission is still undetermined, voice remains unusable even when the app-level voice preference is enabled.

## Diagnostic Signal

The key startup log shape is:

```text
🎤 [VoiceState] app init
   - permission: AVAudioSessionRecordPermission(...)
   - app preference: enabled
   - initial prompt attempted: false
   - voice usable: false
```

This means:

- Voice is enabled in the app preference.
- The microphone permission prompt has not been attempted.
- `VoiceChatService.startSession(...)` will not start real WebRTC because `VoicePermissionManager.isVoiceUsable` is false.

## Fix Pattern

Keep signup onboarding as the primary permission path, but preserve a compatibility fallback from `RemoteGamesTab` for existing users.

The fallback should request microphone permission only when all of these are true:

- The user is on the stable Remote tab context.
- `VoicePermissionManager.isVoiceEnabledInApp == true`.
- `microphoneAuthorizationStatus == .undetermined`.
- `hasAttemptedInitialPrompt == false`.
- The fallback has not already run in this tab session.

This restores voice for existing users without reintroducing surprise prompts from lobby/gameplay screens.

## Non-Blocking Rule

Voice remains an enhancement, not a gate.

If the fallback prompt is denied or skipped:

- Remote matches must still load.
- Lobby navigation must still work.
- `VoiceChatService.startSession(...)` may create an unavailable session.
- Match lifecycle must continue without voice.

## Logging Expectations

Important log points are:

- App startup: `VoicePermissionManager.logState("app init")`
- Settings entry/toggle: `settings task`, `setVoiceEnabled(...)`
- Onboarding completion: final voice preference and permission result
- Remote tab fallback: permission-check decision and result
- Lobby entry: `remote lobby before startSession`

These logs distinguish between:

- app preference disabled
- iOS permission undetermined
- iOS permission denied
- permission granted but later WebRTC/signalling failure

## Do Not

- Do not request microphone permission from `RemoteLobbyView` or `RemoteGameplayView`.
- Do not block match flow while waiting for voice permission.
- Do not treat app preference enabled as proof that iOS microphone permission is granted.
- Do not remove the Remote tab fallback unless all existing users are guaranteed to have passed through onboarding or another stable permission request path.
