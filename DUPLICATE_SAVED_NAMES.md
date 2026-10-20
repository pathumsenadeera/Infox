# FR28: unique names for local saved translations

The requirements describe blocking duplicate saved names. The agreed local-saving
workflow applies that check to app-private copies, separately for each account.
The previous implementation updated a scan by ID but allowed different scans to
use the same display name; this change closes that gap.

Names are compared ignoring letter case, leading/trailing spaces and repeated
whitespace. A different scan using the same name is rejected before writing.
Updating the same scan is allowed. Different accounts can use the same names.
The save dialog remains open and presents a visible and spoken conflict message.
Existing copies are preserved; existing duplicates are not silently renamed.
No backend change or database migration is needed.

## Device checks before committing

1. Save scan A as `My Notes`.
2. Try saving a different scan B as `my notes` and then `  My   Notes  `.
   Both should show and speak the duplicate-name error, leave the dialog open,
   and preserve scan A's text.
3. Change B's name to `Science Notes`. Saving should succeed.
4. Open A and save it again as `My Notes`. It should update the existing copy.
5. Try renaming B to `My Notes`. It should fail without losing either copy.
6. Delete A's local copy, then save B as `My Notes`. It should succeed, and
   server history should still contain both scans.
7. If practical, verify another account on the same phone can use `My Notes`.
8. Try duplicate Sinhala names as well as English names.

## GitHub Desktop commit

Suggested branch: `codex/unique-saved-names`.
Bring these changes onto the branch without restoring old stashes. Commit only:

- `DUPLICATE_SAVED_NAMES.md`
- `sinhala_braille_app/lib/services/saved_translation_service.dart`
- `sinhala_braille_app/lib/screen/audio_player_screen.dart`
- `sinhala_braille_app/test/saved_translation_service_test.dart`

Title:

```text
fix(saves): reject duplicate translation names within each account
```

Description:

```text
Validate local saved-translation names before writing, comparing names without
case differences or redundant whitespace. Reject collisions between different
scans while allowing updates to the same scan and identical names in other accounts.

Perform the check within the serialized write operation so concurrent saves do not
both claim the same name. Preserve existing copies on validation failure and leave
the save dialog open with a visible and spoken message so the user can correct it.

Cover case/whitespace variants, Sinhala names, same-scan updates, account separation,
rename conflicts, name reuse after deletion and concurrent duplicate saves.
No server endpoint or database migration changes.
```
