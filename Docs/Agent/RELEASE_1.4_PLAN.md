# Release 1.4 Development Plan

Scoped 2026-07-22, as 1.3 closes. Cursor executes the specs in
`Docs/Agent/tasks-1.4/`; Claude reviews every PR.

## Theme: survive first contact with real users

1.4 is the first release scoped **across a public launch**. iOS 1.0 is
approved and held; Mac is in review. Whatever real users report in their
first weeks outranks everything planned here — a single recurring App Store
complaint beats any feature on this list.

So 1.4 inverts 1.3's shape: **a light committed core and a large reserve.**

| Task | Title | Module | Review tier | Parallel-safe |
|------|-------|--------|-------------|---------------|
| A2 | Accessibility sweep: remaining iOS surfaces | — | B | in flight |
| A3 | Keyboard nav + Watch/widget accessibility | — | B | in flight |
| H1 | Handoff — iPhone → iPad → Mac | 2.7.7 | B | yes |
| C1 | India compliance tips | 3.6.3 | **A (tax/legal)** | yes |
| O1 | In-app support path + user-controlled diagnostics | — | **A (privacy)** | yes |

A2 and A3 carried over from the 1.3 cycle and land here. H1, C1 and O1 are
independent — no dependency chain, all dispatch at once.

**Reserve: ~40% unassigned** for launch feedback and hotfixes, up from 30%
in 1.3, because this is the cycle where feedback actually arrives.

## Scope decisions — verified against the codebase, not assumed

- **O1 is not analytics, and must not become analytics.** The obvious
  post-launch instinct is "add crash reporting". Checked first: our
  published privacy policy says *"What we collect: nothing"* and *"nothing
  in the app phones home about your behaviour"*, and the privacy manifest
  declares zero collected data types. Meanwhile Apple **already** supplies
  crash, hang and energy diagnostics via App Store Connect under the user's
  own consent, and release builds already emit `dwarf-with-dsym` so they
  symbolicate. The automated signal exists at zero privacy cost; the gap is
  that `support@vittora.app` appears in **zero** Swift files, so a user with
  a bug cannot reach us. O1 builds only that user-initiated path.
- **Handoff (M2.7.7) is genuinely unimplemented.** `NSUserActivity` appears
  only in `TransactionSpotlightIndex.swift`, for indexing. Deferred twice;
  small enough to stop deferring.
- **M3.6.4 unusual-spend alerts and M3.6.5 budget optimization — deferred.**
  Both need per-user history a fresh install does not have. They demo well
  and help nobody in week one.
- **Epic F / Vittora Pro — still gated.** DEC-011 triggers at D30 retention
  >15% or 3–6 months post-launch. The launch has not happened yet.
- **M3.2 ML categorization** needs 100+ transactions per user.
  **M2.4 investment planning** is a large surface needing careful
  financial-advice framing. **M3.1 Vision Pro, M3.4 Family Sharing,
  M3.5 Wave-2 tax** — post-launch.

## Groundwork started in 1.4, shipped later

- **F1 — FinanceKit entitlement request (M3.7.1).** Apple Card / Apple Cash
  auto-import is high value in our primary market and needs an entitlement
  whose approval queue we do not control. File the request in 1.4; build
  once granted.
- **W1 — Year-in-Review "Wrapped" (M3.7.5), spec only.** The strongest viral
  loop in the plan, but **timing-critical: it must ship by late November**
  to be useful in December. Spec now, build in the release that lands before
  then. If it slips past November it is worthless for a full year.

## Process (unchanged — it has held for three releases)

Worktree per task, dedicated simulator per agent, PR into `develop`, merge
`origin/develop` before opening the PR, no committed binaries, no self-merge.
Tier A additionally blocks on explicit reviewer sign-off.

## House rules carried forward

All earned in 1.1–1.3 and enforced in review:

1. No float-literal `Decimal`s.
2. Never derive a displayed total by inverse arithmetic.
3. Test the wiring, not just the pure function.
4. Reset Keychain/App-Group state in tests rather than relying on ordering.
5. **To make a check pass you may only change the code under test.** Not the
   assertion, not the audit configuration, and not the test/demo fixture so
   that the offending input stops being produced. Changing the fixture to
   dodge a check is the same as disabling the check — added after a 1.3 fix
   re-dated demo data so a clipping row fell out of the audited screen,
   leaving the real layout fix unexercised.
