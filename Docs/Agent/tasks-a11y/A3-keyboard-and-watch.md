# A3 — Accessibility sweep: keyboard navigation + Watch/widgets

**Branch:** `feature/a3-keyboard-and-watch-a11y` ·
**PR into:** `develop` · **Review tier: B**

## Context

The second half of P1's deferred list, kept separate from A2 so the two
can run in parallel without conflicting. A2 owns iOS surface audits;
this task owns **macOS/iPad keyboard navigation** and the **Watch and
widget** surfaces.

## Scope

### 1. macOS / iPad keyboard navigation

The Mac app is a first-class target and a keyboard-only user currently
cannot drive it fully.

- **Full tab-order traversal** of every primary screen: sidebar →
  content → detail. Focus must be visible at every stop (SwiftUI focus
  ring or an explicit indicator that meets contrast).
- **Sheets and dialogs**: focus moves into the sheet on present, returns
  to the invoking control on dismiss, Escape cancels, Return commits the
  primary action.
- **Lists**: arrow-key navigation, and Return opens the selected row.
- **Keyboard shortcuts**: verify the existing `handlesAppCommands`
  shortcuts are discoverable in the menu bar and actually fire.
- Destructive actions must **never** be the default focused button in a
  confirmation dialog.

### 2. Watch app accessibility (WA1–WA4 surfaces)

- VoiceOver labels for the snapshot view, crown entry, recent list, and
  the budget-alert overlay. The **crown entry amount** must announce its
  value as it changes — this is the one a blind user cannot use at all
  today.
- Dynamic Type on watchOS: the largest sizes must not clip the amount.
- Confirm the WA3 complications' existing `privacySensitive` handling is
  not disturbed by any label you add.

### 3. Widgets (iOS Home/Lock Screen + StandBy)

- Each widget family exposes a sensible combined accessibility label
  (e.g. "Today's spending, $42.50, 12% below yesterday") rather than
  reading its individual text fragments.
- Verify labels do not leak amounts where `privacySensitive` should
  redact them — a VoiceOver label must not read out what the display
  redacts. **This is the one to get right**; test it.

## Non-goals

Everything A2 owns (iOS screen audits, 44pt sweep, Reduce Motion) — do
not touch those files. Redesigning navigation. Adding new shortcuts
beyond what exists.

## Acceptance criteria

- [ ] macOS: every primary screen fully reachable and operable by
      keyboard alone; focus always visible. Demonstrate with a keystroke
      walkthrough in the PR (list the sequence).
- [ ] Sheets: focus enters on present and restores on dismiss; Escape
      cancels; Return commits. Destructive action is never default-focused.
- [ ] Watch: VoiceOver announces the crown-entry amount as it changes;
      recent list and budget alert are labelled.
- [ ] Widgets: one coherent label per family; **a test asserting the
      accessibility label does not expose an amount that
      `privacySensitive` redacts**.
- [ ] Existing audits (P1's five flows, WA3 complication behaviour) still
      pass — no regressions.
- [ ] `make build-macos` and `make test` green.

## Verification steps

1. macOS: keyboard-only walkthrough, screenshots showing the focus ring
   at several stops.
2. Watch: VoiceOver enabled on the paired Watch simulator; describe what
   is announced during crown entry.
3. Widgets: VoiceOver label output for each family, plus the redaction
   test result.
