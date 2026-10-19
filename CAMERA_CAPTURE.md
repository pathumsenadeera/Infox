# FR17 camera capture: device testing and commit

The camera now prefers the rear lens, explicitly enables automatic focus and
exposure, and requests centre metering when the device supports it. It retains
maximum-resolution JPEG capture, direct file copying, torch support and the
three-second hold countdown. Raw movement cancels the countdown even when the
smoothed guidance still looks aligned. Backgrounding releases the camera;
returning requires camera warm-up and a new hold. Late capture results after
cancellation or camera replacement cannot start an upload.

The camera plugin does not expose a reliable focus-convergence or image-sharpness
result. These changes improve capture conditions but cannot guarantee a sharp
photo. Fixed-focus cameras and minimum focusing distance remain hardware limits.
No HDR or additional camera library is introduced. No backend or database change
is required. Cleanup of saved files and cancellation of uploads already in flight
remain separate work.

## Test on your Android device before committing

1. Install the new debug APK and open the scanner. Confirm the rear camera,
   preview, torch (if supported) and spoken guidance work.
2. Hold a Braille page in the centre at a practical reading distance. After
   warm-up, hold steady for three seconds. Confirm exactly one photo and a
   successful translation.
3. Move or tilt the phone halfway through the countdown. Confirm it resets and
   requires a fresh three seconds when steady again.
4. Press Home or lock the phone during the countdown. Confirm no capture occurs
   in the background. Return and confirm the preview recovers and a fresh
   countdown is required.
5. Use Back during the countdown and immediately after capture begins. Confirm
   the app returns home without a late navigation to the translation screen.
   An upload already submitted is not cancelled by this feature.
6. Test a failed upload with connectivity disabled. Restore connectivity and
   confirm another scan can succeed after the six-second error cooldown.
7. Inspect the saved full-resolution JPEG in Downloads/BrailleScans (or the
   app-specific storage fallback). Zoom into the dots and compare near/far
   distances and normal/dimmer lighting. Check focus, motion blur and torch
   glare. Report any device that never completes the steady countdown.

## Commit after device testing passes

Use your own GitHub Desktop account. Suggested branch: `codex/camera-focus`.
Create it from the branch containing the tested password-recovery changes and
carry these current changes onto it. Do not restore older stashes.

Include only:

- `CAMERA_CAPTURE.md`
- `sinhala_braille_app/lib/screen/live_camera_screen.dart`
- `sinhala_braille_app/lib/services/camera_capture_preparation.dart`
- `sinhala_braille_app/test/camera_capture_preparation_test.dart`
- `sinhala_braille_app/test/widget_test.dart`

Exclude unrelated `.metadata`, `.vscode/` and `android/java_pid4360.hprof`.

Title:

```text
feat(camera): prepare autofocus and require a steady capture window
```

Description:

```text
Prefer the rear camera and explicitly configure automatic focus and exposure
before the three-second capture countdown. Use centre metering when supported,
while allowing devices that reject optional metering regions to use automatic
focus and exposure.

Reject raw movement and stale sensor readings before capture. Reset the hold
when the app backgrounds, release the camera, and initialise it again on resume.
Guard asynchronous capture results so cancellation or camera replacement cannot
start a new upload or navigate to a late translation result.

Preserve maximum-resolution JPEG capture, direct copying and the existing
three-second countdown. Add camera preparation, stability and lifecycle tests,
plus a physical-device test checklist and documented sharpness limitations.

Validation: 30 Flutter tests passed. Add your physical-device results before
committing. No backend or database migration required.
```
