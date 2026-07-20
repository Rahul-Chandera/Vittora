# P2 — StandBy layouts + Spotlight indexing

**Branch:** `feature/p2-standby-spotlight` · **PR into:** `develop` ·
**Review tier: B** · **No dependencies** (parallel-safe)

## Scope

**StandBy (M2.7.3):**
1. Verify/adjust the W2 Home Screen widgets for StandBy: full-color and
   night-mode rendering via `widgetRenderingMode`, legible at distance
   (bump amount type size for `.systemSmall` in StandBy context via
   `showsWidgetContainerBackground`/environment checks). No new widget
   kinds — tune the existing two.

**Spotlight (M2.7.6):**
2. Index transactions via Core Spotlight (`CSSearchableItem`): title =
   payee/note, description = category + formatted amount + date,
   domain per entity. Index incrementally on `notifyChanged(.transactions)`
   (batch, background priority); full reindex on first launch after
   update; deletion/factory-reset removes items (hook the existing
   deletion paths — test this: **Delete All Data must leave zero
   searchable items**, financial data must not outlive the ledger).
3. Tapping a result deep-links to the transaction detail — route through
   the existing `NavigationDestination` handling via `AppState`, W4-style;
   respect App Lock exactly like W4 (pending destination resolves after
   unlock — reuse that mechanism, don't fork it).
4. Privacy: index only on-device (default Core Spotlight behavior);
   nothing leaves the device. Amounts in Spotlight are visible outside
   App Lock by OS design — mirror W3's decision: make indexing a
   **Settings toggle** ("Show transactions in Search", default ON),
   and honor turning it OFF by deleting the index (test).

## Acceptance criteria

- [ ] StandBy: both widgets legible in full-color and night mode
      (simulator screenshots).
- [ ] Spotlight: seeded transaction findable by payee and by category;
      tap opens its detail; with App Lock on, unlock happens first.
- [ ] Delete All Data → Spotlight returns zero Vittora results (test).
- [ ] Settings toggle OFF → index cleared (test).
- [ ] `make test` green; no committed binaries.
