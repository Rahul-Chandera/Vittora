# H1 — Handoff: start on iPhone, continue on iPad/Mac

**Branch:** `feature/h1-handoff` · **PR into:** `develop` ·
**Review tier: B** · **Parallel-safe:** yes

## Context

Plan M2.7.7. We ship one app across iPhone, iPad, Mac and Watch and market
that as the differentiator, but a user who starts entering a transaction on
their phone cannot pick it up on the Mac. Handoff is the Apple-native answer
and it is small — the routing already exists.

Verified before scoping: `NSUserActivity` currently appears **only** in
`TransactionSpotlightIndex.swift` for Spotlight indexing. There is no
continuation support anywhere.

## Reuse, do not reinvent

Deep-link routing is already built and tested. Handoff must feed the same
routing path, not a parallel one:

- `Packages/VittoraCore/…/Domain/Utilities/QuickAddDeepLink.swift`
- `Packages/VittoraCore/…/Domain/Utilities/TransactionSpotlightDeepLink.swift`
- `Vittora/App/AppState.swift` and `Vittora/VittoraApp.swift` (`onOpenURL`)

If a continuation cannot be expressed as one of the existing routes, extend
that route type — do not add a second navigation mechanism.

## Scope

1. **Advertise an activity on these screens**, via `.userActivity(...)`:
   - Transaction list (with the active filter/date range)
   - Transaction detail (specific transaction)
   - Budget detail
   - Report detail (which report, which period)
   - Account detail
2. **Continue on the receiving device** with `.onContinueUserActivity(...)`,
   routing through the existing deep-link handling so iPhone → iPad → Mac all
   land on the same screen with the same state.
3. **In-progress form continuation** for the transaction form only: amount,
   note, category, account, date. If the entity was never saved, carry the
   draft in the activity's `userInfo`; do not create a placeholder record.
4. **Declare the activity types** in `Info.plist` (`NSUserActivityTypes`) for
   every target that advertises or receives them.
5. **Invalidate correctly** — when the underlying record is deleted, or the
   user signs out of iCloud, the activity must not resolve to a dangling ID.
   Continuing to a deleted transaction shows the list, not an error or a crash.

## Non-goals

Handoff to/from the Watch, Universal Clipboard, continuing an in-progress
CSV import, and Siri/Shortcuts changes. Do not touch the Spotlight index.

## Privacy requirement (non-negotiable)

Handoff payloads sync through the user's iCloud account and are covered by
our published policy — but keep them minimal anyway. The activity `userInfo`
carries **identifiers and draft field values only**. Never put a full
transaction list, an account balance, or any aggregate in a `userActivity`.
Set `requiredUserInfoKeys` and mark activities `eligibleForHandoff = true`,
**`eligibleForSearch = false`** (Spotlight is already handled elsewhere and
duplicating it would double-index).

## Acceptance criteria

- [ ] Continuing from iPhone → Mac and iPhone → iPad lands on the same screen
      with the same state, for each of the five screens above.
- [ ] An unsaved transaction draft survives continuation with every field.
- [ ] Continuing to a deleted record falls back to the list without crashing
      — unit test for the resolution failure path.
- [ ] Unit tests for activity encode → decode → route, asserting the routed
      destination equals the source screen's route.
- [ ] A test asserts no activity `userInfo` contains a balance or aggregate.
- [ ] `NSUserActivityTypes` declared in every relevant target's `Info.plist`.
- [ ] `make build-ios`, `make build-macos`, `make test` green.
