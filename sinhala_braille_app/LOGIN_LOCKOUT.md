# Feature 3: server-enforced login lockout

The login screen no longer counts failures locally. It displays a countdown only when the backend returns HTTP 429 with Retry-After seconds. Network failures cannot trigger a local lock. Changing the username lets another account attempt login; returning to the locked username restores its known countdown. After restarting the app, the countdown reappears on the next login attempt because the server retains the lock.

## Device checklist

First deploy the matching backend after applying its `migrate_login_lockout.sql` migration. Use a test account and note its correct password. Do not perform these checks with the admin redirect username.

1. Log out. Disconnect the network and attempt login several times. Connection errors must not disable Login or claim that an account is locked. Reconnect.
2. Enter four incorrect passwords for your test account. Each should show an invalid-credentials error. On the fifth, the app should display a lock and a countdown close to 15 minutes, and disable Login for that username.
3. Fully close and reopen the app. Attempt login with the correct password for the same account. The backend must reject it, restoring the countdown with the remaining time rather than starting another 15 minutes.
4. While locked, change the username to another test account. Login should be enabled and that account should still be able to log in. Log out again.
5. Wait until the original 15-minute deadline passes. Login with the locked account's correct password should work.
6. Verify counter reset: log out, enter four incorrect passwords, then log in correctly. Log out and enter one incorrect password. It should produce an ordinary error, not an immediate lock.
7. Confirm normal login, app reopening, settings and scanning still work.

Optional Beekeeper check: `SELECT user_id, failed_attempts, locked_until FROM infox_db.login_security;`. Times are UTC. The fifth failure creates a deadline; successful login removes that account's row. Do not edit this table to bypass the expiry check during testing.

## Validation and commit

All 20 Flutter tests passed, including server-driven countdown and username switching, and repeated network/ordinary authentication errors without a local lock. Targeted static analysis found no issues. The Android debug APK built successfully using Android Studio's Java runtime and the temporary 4 GB Gradle heap override, without changing project heap settings. APK: `build/app/outputs/apk/debug/app-debug.apk`. Device testing remains pending.

Suggested branch: `codex/login-lockout` (create from your current branch so the session feature is included).

Title: `fix(auth): display server-enforced login lockouts`

Body:

- Remove the screen-local failed-login counter and fixed lockout duration.
- Read Retry-After from authentication errors and show the server's remaining lock time.
- Keep countdowns associated with the attempted username and allow other accounts to log in.
- Prevent connection errors from triggering an account lock and guard duplicate login submissions.
- Add widget coverage for server locks, username switching, and repeated errors without local lockout.
- Validate registration, sessions, navigation and lockout UI with 20 passing Flutter tests; device integration testing remains pending.
- Verify targeted static analysis and Android debug APK compilation.

Include exactly these paths relative to `sinhala_braille_app`:

- `lib/screen/login_screen.dart`
- `lib/services/auth_service.dart`
- `test/widget_test.dart`
- `LOGIN_LOCKOUT.md`

Exclude pre-existing `.metadata`, root `.vscode/`, and `android/java_pid4360.hprof`. Nothing has been staged or committed by the assistant. After successful device testing, update the validation line in your commit body to record the checks actually completed.
