# WA4 — Recent transactions list + budget haptics

**Branch:** `feature/wa4-watch-list-haptics` · **PR into:** `develop` ·
**Review tier: B** · **Depends on:** WA1 merged

## Scope

1. **Recent transactions screen** (M2.6.7): the snapshot's 10 most recent
   entries — name, category icon, signed amount (income green / expense
   red per the watch design tokens from WA2/WA3), relative date. Read-only.
2. **Budget haptic alerts** (M2.6.6): when a received snapshot crosses a
   budget threshold (75%, 90%, 100% of overall budget), play the
   appropriate `WKHapticType` and show a brief alert view. Fire each
   threshold **once per budget period** — persist the last-notified
   threshold + period key in the watch container; crossing detection must
   compare previous vs new snapshot, not re-fire on every update (test
   this dedup).
3. Navigation: root snapshot screen (WA1) → tabs/pages for Entry (WA2)
   and Recent list; haptic alert presented over whatever is frontmost.

## Non-goals

Per-category thresholds, notification-center notifications (phone owns
those), editing/deleting from the watch.

## Acceptance criteria

- [ ] List renders 10 demo transactions matching the phone's most recent.
- [ ] Threshold crossing 74%→91% fires exactly one haptic (90%) and a
      repeat snapshot at 91% fires none (dedup test with injected
      snapshots).
- [ ] New budget period resets the dedup (test).
- [ ] VoiceOver labels on rows and alert.
- [ ] `make test` green; no committed binaries.
