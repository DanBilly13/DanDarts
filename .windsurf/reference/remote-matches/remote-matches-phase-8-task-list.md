# Remote Matches — Phase 8 Push Notifications Implementation Task List

## How to use this task list
This task list is intentionally **gated**.

Rules:
- Work on **one task at a time**
- Do **not** start the next task until the current task is:
  - implemented
  - manually tested
  - reviewed
  - explicitly approved
- If a task reveals a structural issue, stop and update the plan before continuing

Each task is sized to be:
- large enough to produce meaningful progress
- small enough to review safely
- aligned with the agreed architecture:
  - **direct APNs**
  - **explicit Supabase Edge Function invocation**
  - **server-authoritative state**
  - **push is transport, not truth**

---

# Approval model

A task is only considered complete when all four are true:

## 1. Build complete
The code path for the task is implemented.

## 2. Manual test complete
The required test cases for the task were run successfully.

## 3. Review complete
The implementation was reviewed for architecture fit and correctness.

## 4. Explicit approval given
The task was explicitly approved before moving on.

---

# Task 1 — Finalize implementation contracts and data model

## Goal
Lock the implementation contract before writing production push code.

## Includes
- confirm direct APNs as final provider choice
- confirm explicit Edge Function invocation as final delivery approach
- define final token table shape
- define final push payload contract
- define final logout/account-switch behavior
- define final foreground policy
- define final deep-link intent shape

## Deliverables
- final schema for `push_tokens`
- final decision on any consent/status storage
- final payload examples for:
  - challenge received
  - match ready
- final definition of dedupe key / idempotency strategy
- final definition of logout handling
- final definition of `device_install_id`

## Definition of done
- there is no ambiguity left about token shape, payload shape, or delivery path
- implementation can begin without architecture guessing
- any unresolved assumptions are written down explicitly

## Manual approval checklist
- [ ] `push_tokens` schema is agreed
- [ ] payload fields are agreed
- [ ] logout/account-switch handling is agreed
- [ ] foreground policy is agreed
- [ ] `device_install_id` storage approach is agreed
- [ ] idempotency/dedupe rule is agreed

## Approval gate
Do not begin Task 2 until the contract is approved.

---

# Task 2 — Build iOS notification foundation

## Goal
Create the app-side notification foundation without sending real production pushes yet.

## Includes
- notification permission request flow
- notification status observation
- APNs registration
- token receipt handling
- `device_install_id` creation and storage
- notification manager foundation
- denied-permission recovery path using app settings deep link
- foreground handling hook via `UNUserNotificationCenterDelegate`
- local tracking of token sync status

## Excludes
- real server-side push delivery
- challenge-specific push behavior
- ready-match-specific push behavior

## Deliverables
- notification manager integrated into app startup/session flow
- permission states handled cleanly
- APNs token available to app
- `device_install_id` persisted in `UserDefaults`
- denied-permission UX path implemented
- `willPresent` hook implemented for foreground policy

## Definition of done
- the app can request permission and register successfully
- the app can receive and surface an APNs token locally
- foreground policy is wired in code
- denied users have a usable recovery path
- nothing here depends on match events yet

## Manual approval checklist
- [ ] first-run permission flow works
- [ ] denied state is handled cleanly
- [ ] settings deep link works
- [ ] APNs token is captured locally
- [ ] `device_install_id` persists across relaunch
- [ ] foreground delegate path is implemented and understood
- [ ] no challenge-specific logic is mixed in yet

## Approval gate
Do not begin Task 3 until the app-side foundation is approved.

---

# Task 3 — Build token sync and lifecycle management

## Goal
Make token storage reliable and safe before any real push sending happens.

## Includes
- upload APNs token to Supabase
- store token with provider/environment metadata
- store `device_install_id`
- track sync status (`pending`, `synced`, `failed`)
- retry failed sync
- handle token updates
- logout deactivation / detachment behavior
- account-switch rebinding behavior

## Deliverables
- working write path from app to Supabase
- reliable token upsert behavior
- logout/account-switch safety behavior
- token sync retry path
- visibility into sync success/failure

## Definition of done
- the current signed-in user gets the correct token record
- logout prevents future sends to the wrong user/install
- re-login or account switch rebinds correctly
- failed sync is visible and retryable
- no duplicate explosion for the same install/user pair

## Manual approval checklist
- [ ] token row is created in Supabase
- [ ] token row updates correctly on relaunch / refresh
- [ ] environment metadata is stored correctly
- [ ] failed upload can recover on retry
- [ ] logout deactivates or detaches token safely
- [ ] second account on same install does not inherit previous user push association
- [ ] duplicate rows stay under control

## Approval gate
Do not begin Task 4 until token lifecycle management is approved.

---

# Task 4 — Build push delivery Edge Function and observability

## Goal
Implement the server-side delivery path in isolation before wiring it to real match events.

## Includes
- create dedicated Supabase Edge Function for push delivery
- load active token records for target user
- filter by provider/environment
- send to APNs
- log send attempts and outcomes
- handle invalid token responses
- apply dedupe/idempotency rule
- return useful debugging information

## Excludes
- automatic invocation from match flows
- challenge-specific business triggering
- ready-match-specific business triggering

## Deliverables
- deployable Edge Function
- APNs auth/config in place
- structured logs for:
  - attempted send
  - success
  - failure
  - invalid token handling
- test invocation path with a known user/token

## Definition of done
- the function can send a test push to a known device successfully
- the function fails visibly when it should
- logs are good enough to debug delivery issues
- invalid tokens are handled safely

## Manual approval checklist
- [ ] Edge Function deploys successfully
- [ ] test push can be sent to a known token
- [ ] sandbox/production routing behaves correctly
- [ ] failure logging is readable
- [ ] invalid token handling works
- [ ] dedupe/idempotency logic is present

## Approval gate
Do not begin Task 5 until the delivery function is approved.

---

# Task 5 — Build deep-link routing and card highlight flow

## Goal
Make push taps land in the right place before wiring real push events.

## Includes
- app-level notification/deep-link intent model
- route to Remote tab
- fetch authoritative remote state after intent
- resolve target by `matchId`
- scroll to target card
- pulse/highlight card
- clear one-shot intent after use
- behave safely if match no longer exists or state changed

## Deliverables
- simulated push-tap flow that works without live event wiring
- Remote tab can consume pending intent
- highlight behavior is stable and reviewable

## Definition of done
- app can be driven to Remote tab from a simulated notification intent
- the correct card is found by `matchId`
- highlight animation is reliable
- degraded behavior is sensible when item is missing or moved

## Manual approval checklist
- [ ] simulated push tap opens Remote tab
- [ ] target resolves by `matchId`
- [ ] scroll works after data load
- [ ] highlight runs once and clears
- [ ] missing/moved match degrades gracefully
- [ ] mid-navigation case behaves acceptably

## Approval gate
Do not begin Task 6 until routing/highlight is approved.

---

# Task 6 — Wire Challenge Received push end-to-end

## Goal
Ship the first real business event end-to-end: incoming challenge push.

## Includes
- invoke push-delivery Edge Function from authoritative challenge creation path
- send receiver push after successful commit
- use agreed challenge-received payload
- validate background/terminated-app behavior
- validate push tap routing to Remote tab and incoming challenge highlight

## Deliverables
- end-to-end push for incoming challenge
- stable receiver experience when app is backgrounded or closed
- logs tying challenge creation to push invocation

## Definition of done
- creating a challenge results in the receiver getting a real push
- tapping the push lands on the correct Remote destination
- the implementation remains server-authoritative

## Manual approval checklist
- [ ] receiver gets push with app backgrounded
- [ ] receiver gets push with app closed
- [ ] tapping push opens Remote tab
- [ ] incoming challenge is highlighted
- [ ] duplicate sends are not observed in normal flow
- [ ] logs make the full path understandable

## Approval gate
Do not begin Task 7 until Challenge Received push is approved.

---

# Task 7 — Wire Match Ready push end-to-end

## Goal
Ship the second real business event end-to-end: challenge accepted / match ready push.

## Includes
- invoke push-delivery Edge Function from authoritative accept/ready transition
- send challenger push after successful commit
- use agreed match-ready payload
- validate background/terminated-app behavior
- validate push tap routing to Remote tab and ready-match highlight

## Deliverables
- end-to-end push for match ready
- stable challenger experience when app is backgrounded or closed
- logs tying ready transition to push invocation

## Definition of done
- accepting a challenge and producing ready state results in the challenger getting a real push
- tapping the push lands on the correct Remote destination
- the implementation remains tied to committed authoritative state

## Manual approval checklist
- [ ] challenger gets push with app backgrounded
- [ ] challenger gets push with app closed
- [ ] tapping push opens Remote tab
- [ ] ready match is highlighted
- [ ] duplicate sends are not observed in normal flow
- [ ] logs make the full path understandable

## Approval gate
Do not begin Task 8 until Match Ready push is approved.

---

# Task 8 — Hardening pass and negative-case signoff

## Goal
Validate that the system behaves safely outside the happy path before Phase 8 is called done.

## Includes
- permission denied testing
- settings recovery path testing
- token sync failure testing
- logout/account-switch leakage testing
- invalid token handling
- wrong-environment detection
- missing/moved `matchId` handling
- duplicate delivery checks
- foreground policy validation
- shared-device/tester behavior validation

## Deliverables
- final test pass across negative and edge cases
- any cleanup fixes needed for release confidence
- final signoff that Phase 8 behavior is safe and reviewable

## Definition of done
- the system is not only working, but resilient enough for release confidence
- no known correctness issue remains in permission flow, token lifecycle, account safety, routing, or push delivery

## Manual approval checklist
- [ ] denied permission flow is acceptable
- [ ] settings recovery path works
- [ ] token sync failure recovers
- [ ] logout/account-switch does not leak pushes
- [ ] invalid token handling works
- [ ] environment mismatch is understood/tested
- [ ] missing/moved match case is acceptable
- [ ] foreground handling matches product intention
- [ ] shared-device behavior is safe
- [ ] final Phase 8 review completed

## Approval gate
Phase 8 is not complete until this task is approved.

---

# Suggested working rhythm

For each task:
1. implement
2. self-test
3. demo/review
4. record findings
5. get explicit approval
6. move on

If a task spills across too many concerns, split it before continuing.
If a task cannot be approved cleanly, do not continue downstream.

---

# Simple progress tracker

- [ ] Task 1 — Finalize implementation contracts and data model
- [ ] Task 2 — Build iOS notification foundation
- [ ] Task 3 — Build token sync and lifecycle management
- [ ] Task 4 — Build push delivery Edge Function and observability
- [ ] Task 5 — Build deep-link routing and card highlight flow
- [ ] Task 6 — Wire Challenge Received push end-to-end
- [ ] Task 7 — Wire Match Ready push end-to-end
- [ ] Task 8 — Hardening pass and negative-case signoff
