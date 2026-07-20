# WA3 — Watch complications + Smart Stack widget

**Branch:** `feature/wa3-watch-complications` · **PR into:** `develop` ·
**Review tier: B** · **Depends on:** WA1 merged

## Scope

1. WidgetKit-for-watchOS extension with accessory families
   (M2.6.3–2.6.5): **accessoryCircular** (budget ring), 
   **accessoryCorner** (today's spend), **accessoryRectangular**
   (spend + budget remaining), **accessoryInline**; plus the same
   rectangular as the **Smart Stack** entry with a relevance hint after
   each snapshot update.
2. Data source: the WA1 cached snapshot ONLY (shared via the watch app's
   container with the extension — note the watch app and its widget
   extension need their own watch-side App Group; add
   `group.com.enerjiktech.vittora.watch`). No WCSession from the
   extension process.
3. Timeline: single entry per snapshot + `WidgetCenter.reloadAllTimelines()`
   (watch-side) when a new snapshot arrives; midnight rollover entry like
   W2 (reuse `WidgetTimelineDates`).
4. `.privacySensitive()` on all amounts (same rule as W3 — these render on
   the watch face).
5. Stale-data honesty: if the snapshot is older than 24h, show "—" with
   an "open Vittora" hint instead of a stale amount.

## Non-goals

Interactive complications, per-category complications, iOS widget changes.

## Acceptance criteria

- [ ] All four families render on the watch simulator face with demo
      snapshot values matching the phone.
- [ ] Amounts marked `.privacySensitive()`.
- [ ] Stale (>24h) snapshot shows the placeholder state (unit-test the
      staleness rule with injected dates).
- [ ] Midnight rollover entry exists (reuse + test `WidgetTimelineDates`).
- [ ] `make test` green; no committed binaries.
