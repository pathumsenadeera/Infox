# Local translations and scan history: test and commit guide

## Behavior

- Saved locally contains translations explicitly saved by the signed-in user.
- Copies live in app-private storage, separated by account, and survive app restarts.
- Saving the same scan again updates its local copy, including its chosen title.
- Deleting a local copy never sends a server deletion request.
- Past scans lists the authenticated user's server scans, newest first, with Load more.
- Only completed scans containing text can be opened. Pending/error scans remain visible.
- Bookmarks now use account and scan identity. Existing legacy bookmarks are not migrated
  because their old title-based keys cannot reliably identify an owner or scan.
- Captured JPEGs are uploaded directly from temporary camera storage and cleaned up when
  the operation finishes, fails, or notices cancellation. No new public Downloads copy
  is created. Previously exported images are not removed.
- Cancellation stops further polling and late navigation. A request already sent to the
  server may still complete and remains in Past scans; this is not server-side cancellation.
  Temporary file cleanup can wait for an in-flight upload to return or time out.
- App removal/data clearing removes local copies. Offline access requires the app to
  retain a valid signed-in session; this feature does not bypass session expiry.

## Deployment order

1. Commit and merge the backend history endpoint first (see backend SCAN_HISTORY.md).
2. Wait for the server's existing cron deployment/restart. No SQL migration is needed.
3. Install `sinhala_braille_app/build/app/outputs/apk/debug/app-debug.apk` on your device.
4. Complete the checks below, then commit the frontend using your own GitHub Desktop account.

## Device checklist

1. Scan a page. Save its translation with a name. Saved locally must show the exact text
   and title, not sample documents. A blank name must stay in the dialog with an error.
2. Restart the app. Reopen the saved translation, play Sinhala speech, and verify bookmarks.
3. Enable airplane mode while signed in. Saved locally must open and play with an installed
   Sinhala voice; Past scans must show a connection error with Retry.
4. Save the same scan again with another name. There must be only one local copy.
5. Cancel deletion; the copy stays. Confirm deletion using swipe or trash; the local copy
   disappears, while Past scans still contains the scan. Reopen it and save again.
6. Log out and log into a second account on the SAME phone. Neither local saves nor server
   history from the first account should appear. Log back into the first account to verify
   its local copies remain. No second phone is needed.
7. Confirm old completed scans open correctly. Failed/pending scans must not open as fake
   successful translations. Refresh and Load more should work (when over 20 scans exist).
8. Cancel during countdown and just after capture. No late translation page should appear.
   Cancel during processing: returning to history may show the server scan completing.
9. Check Downloads/BrailleScans: new scans should not add image exports. Existing exports
   are intentionally preserved. Confirm normal camera focus/countdown behavior still works.

## Frontend commit

Suggested branch: `codex/local-saves-history`. Carry current changes onto the branch;
never restore old stashes. Include only these files:

- `LOCAL_SAVES_HISTORY.md`
- `sinhala_braille_app/lib/services/saved_translation_service.dart`
- `sinhala_braille_app/lib/services/scan_service.dart`
- `sinhala_braille_app/lib/providers/tts_service.dart`
- `sinhala_braille_app/lib/screen/saved_history_screen.dart`
- `sinhala_braille_app/lib/screen/audio_player_screen.dart`
- `sinhala_braille_app/lib/screen/live_camera_screen.dart`
- `sinhala_braille_app/test/saved_translation_service_test.dart`
- `sinhala_braille_app/test/widget_test.dart`
- `sinhala_braille_app/test/tts_rate_test.dart`

Exclude `android/java_pid4360.hprof` and any unrelated files.

Title:

```text
feat(history): save translations locally and browse authenticated scans
```

Description:

```text
Replace mock saved documents and the placeholder save confirmation with durable,
account-scoped translation files in app-private storage. Support named offline
copies, updating the same scan's copy, and confirmed local-only deletion.

Add Saved locally and Past scans views with loading, error/retry and pagination
states. Open completed server scans and preserve stable scan IDs for local copies
and account-scoped reading bookmarks. Remove sample translation fallback text.
Provide an explicit history-to-dashboard back button and convert account speech
speed multipliers to the Android TTS engine's rate scale for playback and replay.
Wait for actual utterance completion before advancing sections, and invalidate old
playback loops on pause, skip, reset and disposal to prevent skipped opening text.

Upload camera JPEGs directly from temporary storage and clean up after completion,
failure or cancellation. Stop subsequent polling after cancellation without deleting
server scan records or previously exported images.

Add persistence, account isolation, replacement/deletion, invalid data and cancellation
coverage. Record physical-device test results before committing.
```

Additional checks after the playback/navigation fix:

- Set account speech speed to 0.5x, 1.0x and 1.5x in turn and play the same saved
  translation. Speech should become progressively faster; replay must use the
  current setting. The precise sound depends on the installed voice engine.
- Open Saved & history from the dashboard and use the top-left back arrow from
  both tabs. It must return to the dashboard.
- Play a translation with several sections. Confirm the first words and every
  section are spoken in order, including after a slow engine startup. Pause/resume
  restarts the current section; forward/back selects the adjacent section.
- Use Reset bookmark, then Play: reading must start at the beginning. Reopened
  saved translations intentionally resume at their saved section until reset.
