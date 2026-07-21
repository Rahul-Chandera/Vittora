# Release 1.3 Development Plan

Scoped 2026-07-21, while the Mac resubmission is still in review. Cursor
executes the specs in `Docs/Agent/tasks-1.3/`; Claude reviews every PR.

## Theme: value on day one, and taking the India market seriously

Two problems this release addresses, both chosen because they do **not**
depend on launch data we don't have yet:

1. **A new user has no history.** Budgets and reports get better over
   months; a brand-new install has little to say. Financial guidelines
   (50/30/20, emergency fund) produce a useful answer from the first
   month of data — or even from recurring rules alone.
2. **India is a Wave 1 launch market being served in English.** We ship an
   India-specific tax regime comparison but no Hindi. That is a
   half-measure for one of our two launch storefronts.

| Task | Title | Module | Review tier | Parallel-safe |
|------|-------|--------|-------------|---------------|
| G1 | 50/30/20 needs/wants/savings analysis | 3.6.1 | **A (money math)** | yes |
| G2 | Emergency fund tracker | 3.6.2 | **A (money math)** | yes |
| L1 | Hindi localization (hi) | 3.7.2 | B | yes |
| T1 | Themes: OLED black + accent choice | 3.7.3 | B | yes |
| N1 | Notification scheduling & quiet hours | 3.7.7 | B | yes |

All five are independent — no dependency chain this cycle (unlike 1.2's
WA1 gate), so all can dispatch at once on separate simulators.

## Scope decisions — what is deliberately NOT in 1.3

Verified against the codebase before scoping, not assumed from the plan:

- **Mint/YNAB/bank CSV import (M3.7.4) — already shipped.** `CSVImportProfile`
  already has `.mint` and `.ynab` cases with duplicate detection. The
  plan lists it as V2 work; it is done. No task needed.
- **Epic F / Vittora Pro — still gated.** DEC-011 triggers at D30 retention
  >15% or 3–6 months post-launch. The public launch has not happened, so
  there is no retention data. Do not build the paywall.
- **Year-in-Review "Wrapped" (M3.7.5) — deferred on purpose, not dropped.**
  It is the strongest viral loop in the plan (§Viral Growth Loops) but it
  is *timing-critical*: it must ship by late November to be useful in
  December. Schedule it for the release immediately before then.
- **Vision Pro (3.1), Family Sharing (3.4), Advanced ML (3.2)** — each is a
  large new surface or needs data volume we don't have (ML categorization
  needs 100+ transactions per user to be worth anything). Post-launch.
- **Live Activities / Dynamic Island (3.3)** — weak fit. Live Activities
  suit time-bounded events (a delivery, a workout). A month-long budget
  burn-down is not that, and a permanent Dynamic Island presence for
  spending would read as nagging. Revisit only with a concrete moment.
- **Tax expansion to UK/Canada/Australia (3.5)** — Wave 2 country work.
  Premature before the US/India launch proves itself.
- **Handoff (M2.7.7)** — small and still wanted; folded into the next
  polish batch rather than competing with day-one-value work here.

**Reserved capacity: ~30% stays unassigned for launch feedback.** This held
in 1.1 and 1.2 and should hold again — a single recurring complaint in
App Store reviews outranks anything on this list.

## Process (unchanged from 1.2 — it worked)

Worktree per task, dedicated simulator per agent, PR into `develop`, merge
`origin/develop` before opening the PR, no committed binaries, and no
self-merge. Tier A additionally blocks on explicit reviewer sign-off.

House rules carried forward (all four earned in 1.1/1.2 and enforced in
review): no float-literal `Decimal`s; never derive a displayed total by
inverse arithmetic; test the wiring, not just the pure function; reset
Keychain/App-Group state in tests rather than relying on ordering.

## Review workflow

Every PR gets an independent build + run of its critical tests, and for
Tier A a hand-recomputation of the money math before sign-off. Cross-task
merge conflicts are triaged by kind: additive conflicts resolved inline,
semantic or project-file conflicts delegated to the implementing agent
with explicit guidance.
