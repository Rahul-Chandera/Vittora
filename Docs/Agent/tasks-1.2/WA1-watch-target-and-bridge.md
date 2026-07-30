# WA1 — watchOS target + WatchConnectivity data bridge

**Branch:** `feature/wa1-watch-bridge` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (new data path for money)

## Context

First watchOS code in the repo. Read `RELEASE_1.2_PLAN.md` §Architecture
first — it is binding: **the Watch does not share the iPhone's App Group
container**, so `WidgetDataProvider` does not carry over. Phone is the
source of truth; snapshots go phone→watch via `updateApplicationContext`;
queued entries go watch→phone via `transferUserInfo`; no SwiftData/CloudKit
on the watch.

## Scope

1. **watchOS app target** `VittoraWatch` (bundle id
   `com.enerjiktech.vittora.watchkitapp`, watchOS 26, SwiftUI), linked
   against `VittoraCore`. Companion (not standalone-only) app.
2. **`WatchSnapshot`** model in VittoraCore (Codable, Sendable): today's
   spend, budget spent/total, up to 10 recent transactions
   (date/name/amount/type), currency code, `generatedAt`.
3. **Phone side — `WatchBridgeService`**: activates `WCSession` when
   supported; on `AppState.notifyChanged(.transactions/.budgets)` and on
   foreground, builds a `WatchSnapshot` via existing use cases and calls
   `updateApplicationContext` (latest-wins is correct for snapshots — do
   not queue them). Receives `transferUserInfo` payloads of type
   `queuedExpense` and commits via the existing `AddTransactionUseCase`
   (validation stays on the phone).
4. **Watch side — `WatchSnapshotStore`**: `@Observable` cache of the last
   received context, persisted (small JSON in the watch app's own
   container) so a relaunch shows the last snapshot offline; exposes
   `enqueueExpense(amount:categoryID:)` that calls `transferUserInfo`.
5. **Watch UI for WA1 is minimal proof**: single screen showing today's
   spend + budget remaining from the snapshot, with a "last updated"
   footer. Real UI comes in WA2–4.
6. Snapshot payload must stay under the ~65KB application-context limit —
   cap recent transactions at 10 and assert the encoded size in a test.

## Non-goals

Entry UI (WA2), complications (WA3), lists/haptics (WA4), voice,
standalone-watch operation, any store on the watch.

## Money rules (Tier A)

- Amount fields are `Decimal` end-to-end; encode via `Codable` Decimal —
  never `Double` — and never build test money values from float literals
  (AGENTS.md rule 8).
- The phone-side commit path must reuse `AddTransactionUseCase`
  unchanged. If a queued payload fails validation, it must surface in the
  phone app (reuse the existing error surfacing), never be silently
  dropped — test this.

## Acceptance criteria

- [ ] `make build-ios` builds phone + watch app; `make build-macos`
      unaffected; CI green.
- [ ] Paired simulators: phone seeded with demo data pushes a snapshot;
      watch screen shows matching today's-spend value.
- [ ] Queued expense from watch appears in the phone's transaction list
      committed through `AddTransactionUseCase` (verify amount/category).
- [ ] Watch relaunch offline (phone unreachable) still shows the cached
      snapshot with its timestamp.
- [ ] Invalid queued payload surfaces an error on the phone and commits
      nothing (test).
- [ ] Encoded snapshot size test passes; unit tests for snapshot
      encode/decode round-trip (Decimal precision preserved).

## Verification steps (attach evidence to PR)

Use the paired simulator set stated in the dispatch prompt. Screenshots:
watch snapshot screen matching phone dashboard; phone transaction list
showing a watch-queued entry. `make test` summary.
