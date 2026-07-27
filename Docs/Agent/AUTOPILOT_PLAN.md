# Autopilot plan — 2026-07-23 → 2026-07-26 (owner away)

Rahul is away for 3 days. Standing instruction: keep development moving,
release by release, independent of the publish cycle. Everything lands as
PRs for review from the GitHub mobile app; nothing is published.

## Release-train mechanics (adjusted)

One `staging → main` PR per release is impossible with a single staging
branch (later promotions pile into the same PR). Instead:

- `develop` → feature work, as always
- `develop → staging` promotion per release freeze, as always
- **At each freeze, cut `release/x.y` from staging** and open a
  `release/x.y → main` PR titled "Release x.y". These PRs stay open,
  frozen at exactly their release content. Rahul merges the one being
  published, when he publishes it.

## Trains

### 1.4.0 — in flight tonight (automated)
A2 core-flow audit fix → A2 merges → bump 1.4.0 → promote to staging →
cut `release/1.4.0` → open Release 1.4.0 PR. Device QA (real iPhone,
`Docs/Testing/DEVICE_TEST_CHECKLIST.md`) waits for Rahul's return; it
gates publishing, not development.

### 1.4.1 — accessibility fast-follow
Single task: **A2.1** (`Docs/Agent/tasks-1.4.1/A2.1-xl-contrast-debt.md`) —
remove the 8 deferred XCTSkips, fix XL contrast at token level, India tax
(Devanagari) first. Auto-dispatches after A2 merges. Then: review → merge →
bump 1.4.1 → promote → cut `release/1.4.1`.

### 1.5 — proposed scope (specs to follow in `tasks-1.5/`)
Chosen for independence from launch data and from Rahul's presence:

| Task | Title | Module | Tier | Why now |
|------|-------|--------|------|---------|
| L2 | Spanish (es) localization | 3.7.2 | B | US is the primary market; Spanish is its second language. Reuses L1's entire display-time localization infrastructure — the expensive part is already built. |
| W1 | Year-in-Review "Wrapped" | 3.7.5 | **A** (money display) | Timing-critical: must ship well before December. Independent of launch data (renders whatever history exists; demo seed for verification). Building it now removes the November deadline risk entirely. |

Deliberately NOT pulled forward: M3.6.4/M3.6.5 (need per-user history),
M3.2 ML (needs data volume), Epic F (gated on DEC-011), FinanceKit build
(entitlement not granted — the request paperwork needs Rahul's Apple
account), Vision Pro / Family Sharing (large new surfaces that deserve an
owner decision), Live Activities (previously judged a weak fit).

### 1.6 — outline only, no build (owner decisions needed)
Candidates to decide together: M3.5 Wave-2 tax (UK first — Tier A, large),
M2.4 investment planning (advice-framing risk). Planning notes only.

## Guardrails (hard, for the whole 3 days)

1. **Nothing merges to `main`.** Release PRs are opened and held.
2. **Nothing is submitted to the App Store**; no store metadata changes.
3. **No website deploys** without explicit approval.
4. **Tier A PRs**: my full review gate applies (independent verification,
   hand-recomputation), and they additionally carry a `HOLD: owner
   re-review` note — merged into `develop` only if every gate passes,
   flagged for Rahul's re-review on return before any release containing
   them is published.
5. House rules 1–9 (AGENTS.md) enforced on every PR, as in 1.1–1.4.
6. Launch feedback outranks this plan: if App Store reviews or crash
   reports surface a real user issue, it preempts 1.5 work.

## Progress visibility while away

- Every milestone = a PR or PR comment on `Rahul-Chandera/Vittora`
- GitHub mobile notifications: watch for "Release 1.4.0" and "Promote"
  PRs, and the A2.1 / L2 / W1 feature PRs
- This document is updated if the plan changes materially
