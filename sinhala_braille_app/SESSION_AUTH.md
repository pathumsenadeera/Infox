# Feature 2: secure mobile sessions

The app stores session credentials using platform secure storage. It stores neither plaintext passwords nor password hashes locally. Startup removes legacy password and profile preferences; legacy user IDs alone cannot authenticate a user.

Access lasts 30 minutes and refresh renews it within a fixed 30-day window after login. Expired or revoked sessions clear authentication and remove protected routes. A valid stored session can remain available while offline; server revocation is detected on the next successful server contact. Logout requires connectivity so the server can revoke the session. Failed logout leaves the session intact and displays an error.

## Device checks before committing

Use the matching backend after its session-table migration. The old server cannot issue these sessions. Do not treat isolated automated tests as proof that the deployed backend is configured correctly.

1. Upgrade the previously installed app: it should require login once, even if the old app remembered you.
2. Check incorrect and correct login; close and reopen the app after correct login and confirm it restores your account.
3. Change your username and settings, restart, and verify persistence. Capture and complete a scan to check authenticated upload and polling.
4. Leave the app logged in for over 30 minutes, then change settings or scan. It should renew silently. The 30-day absolute expiry is covered by automated clock tests; testing it on a server requires an isolated test environment.
5. Disconnect the network and reopen the app. Try a server operation and logout: failures should be shown without silently signing you out. Reconnect and retry logout; Back must not return to a protected screen. Restart and confirm you remain signed out.
6. Log in on two devices if available. Submit an incorrect current password; it should fail. Change the password correctly; the current device should return to login and the second should be signed out on its next server request. The old password should fail and the new one should work.
7. Log in again and navigate into a nested screen. Revoke that test account's session on the test backend, then trigger a server request. Confirm the app returns to login and Back cannot reopen the protected route.

Automated validation: all 18 Flutter tests passed, covering registration, renewal, revocation, storage errors, offline behavior, logout and navigation. Targeted analysis of the session services, provider, app root and new tests found no issues. The Android debug APK built successfully using Android Studio's Java runtime and a temporary 4 GB Gradle heap override; the default 1.5 GB heap ran out of memory. Project heap settings were left unchanged. APK: `build/app/outputs/apk/debug/app-debug.apk`.

## Commit prepared for the user

Title: `feat(auth): store secure sessions and remove saved passwords`

Body:

- Replace locally saved passwords and trusted user IDs with platform-secured session credentials.
- Remove legacy password/profile preferences during startup and validate restored sessions with the server.
- Automatically renew short-lived access credentials, coalesce concurrent renewals, and retry unauthorized requests once.
- Prevent late requests from restoring a cleared session and handle secure-storage failures safely.
- Authenticate settings, scan upload/polling, username updates, and password changes.
- Revoke sessions through server logout and clear protected navigation when authentication ends.
- Preserve exact password input and validate password changes exclusively on the backend.
- Disable Android backup for the secure-storage integration and register the new plugin on supported desktop targets.
- Add session and navigation regression tests; all 18 Flutter tests pass.
- Verify targeted static analysis and Android debug APK compilation; device integration testing remains pending.

Include these paths relative to `sinhala_braille_app`:

- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`
- `lib/providers/user_provider.dart`
- `lib/screen/change_password_screen.dart`
- `lib/screen/login_screen.dart`
- `lib/screen/profile_screen.dart`
- `lib/services/auth_service.dart`
- `lib/services/session_service.dart`
- `lib/services/settings_service.dart`
- `lib/services/scan_service.dart`
- `pubspec.yaml` and `pubspec.lock`
- `test/session_service_test.dart` and `test/widget_test.dart`
- `linux/flutter/generated_plugin_registrant.cc` and `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc` and `windows/flutter/generated_plugins.cmake`
- `SESSION_AUTH.md`

Exclude pre-existing `.metadata` and root `.vscode/` changes. Exclude any `android/java_pid*.hprof` crash dump from the failed build. Review the diff and commit using your own account after device testing; nothing was staged or committed by the assistant.
