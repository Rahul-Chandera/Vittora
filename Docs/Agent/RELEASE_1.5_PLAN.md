# Release 1.5 Development Plan

Scoped 2026-07-23 while the owner is away (see `AUTOPILOT_PLAN.md`).
Cursor executes the specs in `Docs/Agent/tasks-1.5/`; Claude reviews every PR.

## Theme: reach and retention, without needing launch data

Both tasks were chosen because they depend on neither App Store feedback
nor the owner's presence, and because each has a reason to be built *now*
rather than later.

| Task | Title | Module | Review tier | Parallel-safe |
|------|-------|--------|-------------|---------------|
| L2 | Spanish (es) localization | 3.7.2 | B | yes |
| W1 | Year in Review ("Wrapped") | 3.7.5 | **A (money display)** | yes |

- **L2** is the highest-reach localization available: Spanish is the second
  language of our primary market. L1 already built the display-time
  localization architecture, so this is mostly translation plus layout
  verification — high value per unit of risk.
- **W1** is *deadline-bound*. It must ship before December to be worth
  anything, and it is the strongest sharing mechanic in the plan. Building
  it in July converts a November scheduling risk into ordinary work.

Both are independent — no dependency chain, both dispatch at once on
separate simulators.

## Deliberately not in 1.5

- **M3.6.4 unusual-spend alerts / M3.6.5 budget optimization** — need
  per-user history a young install does not have.
- **M3.2 ML categorization** — needs ~100+ transactions per user.
- **Epic F / Vittora Pro** — gated on DEC-011 (D30 >15%, or 3–6 months
  post-launch). The app went live 2026-07-23; there is no retention data.
- **M3.7.1 FinanceKit** — blocked on an Apple entitlement request that
  needs the owner's Apple account.
- **M3.1 Vision Pro, M3.4 Family Sharing, M3.5 Wave-2 tax, M2.4 investment
  planning** — each is a large new surface or carries advice-framing risk;
  they deserve an owner decision rather than an autopilot one.

## Reserve

~40% of capacity stays unassigned. Launch feedback outranks this plan: a
recurring App Store complaint or a crash report preempts both tasks.

## Process (unchanged)

Worktree per task, dedicated simulator per agent, PR into `develop`, merge
`origin/develop` before opening the PR, no committed binaries, no self-merge.
Tier A additionally blocks on explicit reviewer sign-off.

## House rules enforced in review

Rules 1–9 in `AGENTS.md`. Two earned recently and especially relevant here:

- **Rule 9** — to make a check pass, change only the code under test; never
  the assertion, the audit configuration, or the fixture.
- **The A2 lesson (new):** when an accessibility audit flags a *disabled*
  control's dimmed label, do not remove `.disabled` to force contrast. A
  disabled control is exempt from the contrast audit; an enabled toolbar
  item is fully audited and navigation-bar content does not scale with
  Dynamic Type. That mistake cost four CI rounds on PR #155.
