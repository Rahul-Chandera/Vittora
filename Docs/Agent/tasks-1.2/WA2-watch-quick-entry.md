# WA2 — Watch quick expense entry

**Branch:** `feature/wa2-watch-entry` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off** (money write path) ·
**Depends on:** WA1 merged

## Scope

1. Entry flow on the watch (M2.6.1): amount via **Digital Crown**
   (`digitalCrownRotation`, 0.50 steps, haptic detents) with tap-to-type
   fallback; then a category grid (top 8 by recent usage from the
   snapshot; icons + colors); confirm screen → `enqueueExpense` (WA1).
2. Pending-state UX: entry shows as "syncing" until the phone confirms
   (next snapshot includes it); if the phone is unreachable the entry
   stays queued — WatchConnectivity guarantees delivery — and the UI says
   so plainly. Never imply a commit that hasn't happened.
3. Amounts are `Decimal`; crown steps map to exact cents (no Double
   accumulation drift — accumulate in cents as Int, convert once; test
   that 500 crown-steps of 0.50 equal exactly `Decimal(string: "250.00")`).
4. Localized currency symbol from the snapshot's currency code.

## Non-goals

Income/transfer entry, notes/payees, editing, voice.

## Acceptance criteria

- [ ] Full flow on paired sims: crown to `12.50` → Dining → confirm →
      entry lands in phone list as `12.50` Dining expense.
- [ ] Cents-accumulation unit test (no `Double` drift; exact Decimal).
- [ ] Phone-unreachable case: entry queues, UI shows pending, delivers
      after reconnect (verify with phone app terminated then relaunched).
- [ ] VoiceOver labels on amount, categories, confirm (P1 will audit, but
      don't ship a new surface broken).
- [ ] `make test` green; no committed binaries.
