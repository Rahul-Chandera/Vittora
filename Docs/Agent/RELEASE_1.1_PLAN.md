# Release 1.1 Development Plan

Parallel-track development while 1.0 launch completes. Cursor executes the
task specs in `Docs/Agent/tasks-1.1/`; Claude + Rahul act as expert
reviewers on every PR.

## Scope

**Theme: daily-habit surface area.** Widgets put Vittora on the Home/Lock
Screen every day — the highest retention-per-effort work in the plan
(Module 2.7) — plus report/export upgrades (Module 2.8) that deepen the
monthly-review habit.

| Task | Title | Module | Review tier | Depends on |
|------|-------|--------|-------------|------------|
| W1 | Widget extension scaffold + shared data access | 2.7 | **A (pre-merge)** | — |
| W2 | Home Screen widgets: Today's Spending, Budget Remaining | 2.7.1 | B | W1 |
| W3 | Lock Screen accessory widgets | 2.7.2 | B | W1 |
| W4 | Quick-add deep links + interactive widget button | 2.7.5 | B | W1 |
| W5 | App Shortcuts: spending query + add-expense phrase | 2.7.4 | B | W1, W4 |
| R1 | PDF export for Monthly Overview & Annual Summary | 2.8.1 | B | — |
| R2 | Subscription audit report | 2.8.7 | B | — |
| R3 | Cash-flow forecast report (stretch — only if capacity remains) | 2.8.5 | **A (pre-merge)** | — |

**Deliberately out of scope for 1.1:**
- Epic F / StoreKit / Vittora Pro — DEC-011 trigger (D30 >15% or 3–6
  months) has not fired.
- Apple Watch app (2.6) — new platform surface + watchOS review pipeline;
  deferred to 1.2.
- StandBy (2.7.3), Spotlight (2.7.6), Handoff (2.7.7) — after the core
  widget set proves out.

**Reserved capacity:** ~30% of the cycle stays unassigned for launch
feedback. Real user reviews outrank every pre-planned task; expect a
1.0.1 patch (the privacy-shield redaction fix is already queued on
`develop`) shortly after release.

## Process rules (Cursor)

1. **Branching:** one branch per task, named as specified in the task
   file. PR into `develop` — never `staging`/`main`, never direct pushes.
   Every task ends in an open PR; no orphaned branches.
2. **Hotfix lane stays clear:** launch-week hotfixes branch from `main`.
   Feature work must leave `develop` releasable after every merge — no
   half-wired UI, no dead settings toggles.
3. **Review tiers:**
   - **Tier A (pre-merge review):** anything touching money math,
     balances, persistence/store configuration, sync, or deletion. The PR
     waits for explicit reviewer sign-off — no self-merge, even with green
     CI.
   - **Tier B (post-merge review):** UI, widgets, reports rendering.
     Green CI + acceptance criteria met → may merge; reviewer audits
     after.
4. **Definition of done** (every task): all acceptance criteria pass; the
   verification steps in the spec were actually executed and evidence
   (screenshots / test output) is in the PR description; unit tests added
   where the spec requires; `make build-ios`, `make build-macos`, and
   `make test` green in CI.
5. **House rules** (from AGENTS.md, non-negotiable): all user-facing text
   via `String(localized:)`; no force unwraps in production code; no
   third-party dependencies; offline-first behavior preserved; targeted
   tests for tax/sync/security/deletion changes.
6. **Shared-code placement:** logic needed by both the app and the widget
   extension goes in `Packages/VittoraCore` (it exists precisely for
   this), not duplicated in targets.

## Review workflow (Claude + Rahul)

Each Cursor PR gets: correctness review of the diff, a live run of the
feature (simulator/device, the way the 1.0 fixes were verified), and a
check that acceptance criteria match observed behavior — not just the PR
description. Tier A additionally blocks merge until sign-off is posted on
the PR.
