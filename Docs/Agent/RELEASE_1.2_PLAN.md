# Release 1.2 Development Plan

Second parallel-track cycle. Theme: **the wrist** (Apple Watch, Module 2.6 —
the last unshipped V1 module) plus a small polish batch. Same process as
1.1 (`RELEASE_1.1_PLAN.md`): Cursor executes specs in
`Docs/Agent/tasks-1.2/`, Claude + Rahul review every PR.

1.1 (widgets W1–W5, reports R1–R3, v1.1.0 build 3) is frozen into
`staging` for QA; 1.2 work lands on `develop`. No separate release branch
— the develop → staging → main flow covers it.

## Scope

| Task | Title | Module | Review tier | Depends on |
|------|-------|--------|-------------|------------|
| WA1 | watchOS target + WatchConnectivity data bridge | 2.6 | **A (pre-merge)** | — |
| WA2 | Watch quick expense entry (crown + category grid) | 2.6.1 | **A (pre-merge)** | WA1 |
| WA3 | Watch complications + Smart Stack widget | 2.6.3–5 | B | WA1 |
| WA4 | Recent transactions list + budget haptics | 2.6.6–7 | B | WA1 |
| P1 | Accessibility audit: VoiceOver, Dynamic Type, contrast | 3.7.6 | B | — |
| P2 | StandBy layouts + Spotlight indexing | 2.7.3, 2.7.6 | B | — |

**Deliberately out of scope for 1.2:**
- Watch voice entry with parsed amounts ("add 500 for groceries",
  M2.6.2) — parameterized intents were deferred from W5 for the same
  reason: headless entry needs category/account disambiguation design.
  One deferral, recorded twice, decided once.
- Epic F / StoreKit / Vittora Pro — DEC-011 trigger (D30 >15% or 3–6
  months post-launch) has not fired. Widgets/Watch exist to move that
  number; don't build the paywall before the data.
- Vision Pro, ML, Live Activities, Wave-2 tax — Phase 3, after 1.2.

**Reserved capacity:** ~30% for launch feedback, unchanged. 1.0 public
launch feedback outranks every task above; expect a 1.0.1/1.1.x patch
lane to open once reviews land.

## Architecture constraint the Watch track must respect

**The Watch does not share the iPhone's App Group container.** It is a
separate device with its own storage — `WidgetDataProvider`'s
group-store approach does NOT carry over. The chosen architecture
(WA1, binding for WA2–4):

- **Phone remains the source of truth.** No SwiftData/CloudKit store on
  the watch in 1.2.
- **Snapshots flow phone → watch** via `WCSession`
  `updateApplicationContext` (latest-wins: today's spend, budget
  remaining, recent transactions, currency code). Watch caches the last
  snapshot for offline glances.
- **Entries flow watch → phone** via `transferUserInfo` (queued,
  delivery-guaranteed). The phone validates and commits through the
  existing use cases — the watch never writes money data itself.
- Complications read the cached snapshot only.

This keeps offline-first semantics honest on both wrists of the sync and
keeps every money write on the already-tested phone path.

## Process rules

Identical to 1.1 (worktree per task, dedicated simulator per agent, PR
into `develop`, no committed binaries, merge develop before opening PR,
Tier A blocks on reviewer sign-off) plus the accumulated house rules:

1. **No float-literal `Decimal`s** (AGENTS.md rule 8 — cost R2 two CI
   cycles).
2. **No inverse-arithmetic totals** — every displayed number sums its own
   column (R2's 898.999… lesson).
3. **Test the wiring, not just the pure function** (W5's App Lock bypass
   lesson).
4. **Keychain/App Group state leaks between tests** — use
   `UITestSupport`'s reset helpers; never rely on test order (bit us
   three times in 1.1).
5. Watch tasks: simulator pairing — use the dedicated paired
   iPhone+Watch simulator pair stated in each spec; never repair or
   erase simulators you were not assigned.
