# W4 — Quick-add deep links + interactive widget button

**Branch:** `feature/w4-quick-add-links` · **PR into:** `develop` ·
**Review tier: B** (post-merge review) · **Depends on:** W1 merged

## Context

The app registers the `vittora://` URL scheme (see `CFBundleURLTypes` in
`Vittora/Info.plist`) but currently routes only split-group URLs
(`appState.openSplitGroup(from:)` in `VittoraApp`). Quick Actions on the
Dashboard already open `QuickEntryView` with a preselected type.

## Scope

1. Extend URL routing with `vittora://add?type=expense|income|transfer`:
   opens the app directly into the existing QuickEntry flow with that type
   preselected. Route through `AppState` the way split-group links do —
   don't build a parallel router.
2. If App Lock is enabled, the lock screen must still gate the app first;
   the deep link resolves **after** successful unlock (store the pending
   destination, don't bypass the lock).
3. Add a **"+ Add expense" button** to the medium Today's Spending widget
   (W2) that opens the app via the deep link. (A plain `Link`/widgetURL is
   acceptable; a full in-widget entry form via App Intents is out of
   scope.)
4. Unit-test the URL parser (valid types, unknown type falls back to
   opening the app normally, malformed URLs ignored).

## Non-goals

In-widget transaction entry without opening the app; Siri phrases (W5);
macOS URL handling changes beyond compiling.

## Acceptance criteria

- [ ] `xcrun simctl openurl booted "vittora://add?type=expense"` opens
      QuickEntry with Expense preselected (same for income/transfer).
- [ ] With App Lock enabled, the same URL shows the lock screen first and
      lands on QuickEntry only after unlock.
- [ ] Unknown/malformed `vittora://` URLs open the app without crashing.
- [ ] Widget button tap opens QuickEntry (verify on simulator).
- [ ] URL-parser unit tests pass.

## Verification steps

1. Screen recording or screenshot sequence: widget tap → QuickEntry open
   with Expense preselected.
2. `simctl openurl` outputs for all three types + one malformed URL.
3. App Lock path: enable lock, fire URL, screenshot lock screen, unlock,
   screenshot QuickEntry.
4. `make test` summary.
