# Feature 4: password recovery

The placeholder reset-link screen now requests a real email code. Users enter the eight-digit code and confirm their new password inside the app. Errors are displayed and spoken, with focus moved to invalid fields. Resend has a 60-second UI cooldown; the backend independently enforces its limits. Passwords and codes are held only in screen memory, cleared on completion/email changes, and never stored in preferences. Successful reset returns to a fresh login screen, clearing any old local lockout countdown.

## Device checklist before committing

First apply the backend migration, configure Resend and the reset secret privately on the server, and deploy the backend as described in its `PASSWORD_RECOVERY.md`. Expected sender: `InfoX <noreply@mail.projectinfox.tech>`. Install the newly built APK; use a test account with a real mailbox you control.

1. Open Forgot Password. Submit an invalid email: the screen should show/speak an error and focus the email field. Disconnect the network and submit a valid email: it should show a connection error without claiming success or advancing.
2. Reconnect and request a code for your test account. Confirm the generic request message and receipt of an eight-digit code from the expected sender. Check spam if needed. The app should show code, new-password and confirmation fields. No API key belongs in the app.
3. Request for an unregistered address you control: the app should show the same generic response, with no account-existence disclosure.
4. Try a missing/short code, an empty password, and mismatched confirmation. Each should produce the relevant validation message. Submit an incorrect eight-digit code: the server must reject it and keep the form available.
5. Submit the latest code with matching new passwords. Confirm success, return to login, and verify the old password fails while the new password works. A reused code must fail. Password whitespace must remain exact.
6. Request another code, wait at least 60 seconds, then resend. The previous code must fail and the newest code must work. Immediate repeated requests must not send additional emails. The server permits at most five sends in its one-hour window, even across app restarts; plan testing accordingly.
7. For a fresh code, submit five incorrect eight-digit codes, then the correct one. It must fail after the guess limit. For a separate fresh code, wait over 10 minutes before submitting it: it must fail after expiry. Both behaviors have automated coverage if you cannot finish these timed checks now; record what you actually tested.
8. Lock your test account with five wrong login passwords. Use email recovery to reset it, then immediately log in with the new password: recovery should clear the login lock.
9. If a second device is available, keep it signed in before a reset. After resetting on the first device, trigger a server request on the second: it should return to login. Otherwise record that device coverage is unavailable; automated tests cover two sessions.
10. Check normal login, app reopening, settings and scanning. Review spoken messages, scrolling with the keyboard open, and Show passwords on your device.

Backend tests mock email delivery; actual inbox delivery must be checked on your server. The request response intentionally cannot distinguish unknown accounts, throttling, and delivery failures. If no email arrives, verify the sender domain/API configuration and provider dashboard privately, without sharing keys or codes.

## Validation and commit

All 23 Flutter tests passed, including a phone-sized recovery flow, input validation, exact-password submission, network failure, invalid codes, clearing inputs on email changes, and returning to login. Targeted static analysis found no issues, and the Android debug APK built successfully with Android Studio's Java runtime and a temporary 4 GB Gradle heap override. APK: `build/app/outputs/apk/debug/app-debug.apk`. Device and live-email testing remain pending.

Suggested branch: `codex/password-recovery`.

Title: `feat(auth): implement email-code password recovery in the app`

Body:

- Replace placeholder reset-link confirmation with the backend email-code recovery flow.
- Add code, new-password and confirmation inputs with visible and spoken validation.
- Preserve exact passwords, validate bcrypt's byte limit, and keep passwords/codes out of persistent storage.
- Handle request/reset failures, disable duplicate submissions, and show a resend cooldown.
- Clear sensitive inputs after success or email changes and return to a fresh login screen after reset.
- Add injectable recovery service and phone-sized widget regression coverage.
- Validate the app with 23 passing Flutter tests; device and live-email checks remain pending.
- Verify targeted static analysis and Android debug APK compilation.

Include exactly these files relative to `sinhala_braille_app`:

- `lib/screen/forgot_password_screen.dart`
- `lib/services/auth_service.dart`
- `lib/services/password_recovery_service.dart`
- `test/widget_test.dart`
- `PASSWORD_RECOVERY.md`

Exclude pre-existing `.metadata`, root `.vscode/`, and `android/java_pid4360.hprof`. Nothing has been staged or committed by the assistant. After device testing, update the commit body with the checks actually completed.
