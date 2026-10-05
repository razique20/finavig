# App Lock — Complete-Flow & UI Test Report

Date: 2026-10-05
Branch: `main`
Feature: App Lock (local 6-digit passcode + optional biometric unlock)

## Summary

| Check | Command | Result |
| --- | --- | --- |
| Full test suite | `flutter test` | **377/377 passing**, exit 0 |
| App Lock suite | `flutter test test/app_lock_test.dart` | **35/35 passing**, exit 0 |
| Static analysis (touched files) | `flutter analyze <app-lock + money files>` | 47 issues, **all pre-existing `info`** (deprecated `withOpacity`), no errors/warnings |

No regressions across the 44 test files in `test/`.

## Scope

The App Lock convenience passcode is a device-local re-entry shortcut layered on
top of the Supabase session — it never replaces the account password. This
report verifies the complete user journey end to end, plus the UI states the user
actually sees.

## Flows verified

| # | Flow | How it is covered |
| --- | --- | --- |
| 1 | **Enable** — choose + confirm a 6-digit passcode | `PasscodeSetupScreen flow`, `ProfileSecuritySection`, `maybeOfferAppLockSetup` |
| 2 | **Storage safety** — only a salted, iterated hash is persisted | `AppLockService` "enable stores only a salted hash" |
| 3 | **Cold-start lock** — app opens locked over live content | `AppLockGate flow` "locks on cold start and unlocks with the right passcode" |
| 4 | **Unlock** — correct passcode reveals the app; wrong shows an error and keeps the lock | `AppLockGate flow` (wrong → "Incorrect passcode"; right → overlay dismissed) |
| 5 | **Post-login offer** — one-time prompt, decline persisted | `maybeOfferAppLockSetup (post-login)` (accept, decline, and "already has a passcode") |
| 6 | **Settings toggle on** — switch runs set-up and flips On | `ProfileSecuritySection` "tapping the switch on runs set-up" |
| 7 | **Settings toggle off** — requires the passcode; wrong rejected | `ProfileSecuritySection` "tapping the switch off requires the passcode" |
| 8 | **Change passcode / verify prompt** | `promptForPasscode`, `changePasscode` unit test |
| 9 | **Escalating lockout** — 5 wrong attempts, persisted across relaunch | `AppLockService` lockout tests |
| 10 | **Forgot passcode** — sign out, clear the lock, reveal the app | `AppLockGate flow` "Forgot passcode signs out…" |
| 11 | **Never locks while signed out** | `AppLockGate flow` "never locks while signed out" |
| 12 | **No Overlay / tooltip crash on the overlay layer** | `AppLockGate flow` "biometric button renders above the Navigator" |
| 13 | **Keyboard overflow in money sheets** (7px bug) | `test/transaction_form_sheet_test.dart` (4/4) |

### UI tests added in this pass

Four new widget tests close the remaining user-facing gaps in
`test/app_lock_test.dart`:

1. **Complete flow** — post-login offer → accept → set up passcode → cold start
   comes up locked → correct passcode reveals the app. One test walks the whole
   sequence a real user performs.
2. **Lockout overlay** — after five wrong attempts the panel switches to
   `Locked for now`, the countdown message renders, the correct passcode is
   refused, and the "Forgot passcode?" escape hatch is disabled.
3. **Biometric auto-unlock (success)** — on cold start a matching biometric
   dissolves the lock and shows the app.
4. **Biometric auto-unlock (cancelled)** — a cancelled/failed biometric leaves
   the passcode lock in place, shows the fingerprint button, and the passcode
   still unlocks as the fallback.

## Notable findings

- **The locked child stays mounted.** `AppLockGate` renders the app content and
  the lock overlay as siblings in a `Stack`, so the protected content remains in
  the widget tree (visually covered) while locked. Tests must assert on the
  overlay's presence/absence, not on the content being absent. Two initial
  assertions were corrected for this reason.
- **The lockout countdown ticker schedules a frame every second** while a lockout
  is active, so `pumpAndSettle()` cannot be used during that state (it would spin
  until timeout). The lockout test advances time explicitly with `tester.pump()`.

## Limitations

- The real OS biometric prompt cannot be exercised in a headless host; the
  `BiometricService` test overrides (`supportedOverride`,
  `authenticateResultOverride`) stand in for the platform channel. Success,
  cancellation and "unavailable hardware" branches are covered.
- The **>30s background → resume re-lock** path is time-based
  (`DateTime.now()`), so it is not unit-tested; the cold-start path, which shares
  the same `lock()`/`shouldBlock` state machine, is covered.
- Native builds were verified in earlier passes (`flutter build apk --debug`,
  `flutter build ios --debug --no-codesign`); this pass re-ran Dart tests and
  analysis only.

## Commands used

```bash
flutter test
flutter test test/app_lock_test.dart
flutter analyze lib/services/app_lock_service.dart lib/services/biometric_service.dart \
  lib/widgets/passcode_pad.dart lib/screens/app_lock_screen.dart lib/widgets/app_lock_gate.dart \
  lib/screens/app_lock_flows.dart lib/screens/profile/app_lock_section.dart lib/screens/login_screen.dart \
  lib/services/auth_service.dart lib/app.dart lib/main.dart
```
