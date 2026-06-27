# Cursor Handoff — Vittora Audit Remediation

You (Cursor) are implementing the remediation defined by this repo's pre-launch audit. A separate reviewer will review each change, so your job is to ship **small, correct, well-tested, easy-to-review** units of work — not to do everything at once.

## Read these first (source of truth)
1. `Docs/Audit/EXECUTION_PLAN.md` — the task list. **This is your work queue.** Each task has an ID, file targets, steps, acceptance criteria, the test to add, and a verification command.
2. `Docs/Audit/PRELAUNCH_AUDIT_2026-06-27.md` — *why* each task exists (evidence + severity). Read the relevant finding before implementing a task.
3. `AGENTS.md` / `CLAUDE.md` — project contributor rules (these override anything generic).
4. `Docs/Architecture/SYSTEM_MAP.md`, `Docs/Data/SCHEMA_MAP.md`, `Docs/Tax/RULE_COVERAGE.md` — orientation for sync, schema, and tax work.

## Golden rules (non-negotiable)
- **Branch per task** off `develop`: `fix/<task-id>-<slug>` (e.g. `fix/A2-transfer-pair-id`). **Never** commit to `develop` or `main`.
- **One task = one branch = one PR.** Keep diffs focused; do not bundle unrelated tasks. (You may combine two tightly-coupled tasks only if the plan lists one as a hard `Dep:` of the other and they're trivial — note it in the PR.)
- **Both builds + tests must be green before you mark a task done:** `make build-ios`, `make build-macos`, and the task's test command.
- **No force-unwraps** in production code. **All user-facing text via `String(localized:)`.** **No new third-party dependencies** (Apple frameworks only). Preserve **offline-first** behavior. Treat financial data as sensitive.
- **Financial correctness is paramount.** For any money math (balances, transfers, splits, tax, rounding), you **must** add an automated test proving the acceptance criterion. Use `Decimal`, never `Double`, for money.
- **Schema changes are CloudKit-backed and additive-only.** New SwiftData properties must be optional or have defaults; bump the versioned schema and add a `MigrationStage` (lightweight where possible) and a migration round-trip test. Never rename/remove a property without a custom migration.
- **Stay in scope.** Do not refactor beyond the task. If you spot something else, note it in the PR "Out of scope observed" section — don't fix it.
- **Update any doc your change invalidates** (`SYSTEM_MAP.md`, `SCHEMA_MAP.md`, `RULE_COVERAGE.md`, `RELEASE_CHECKLIST.md`, `DECISION_LOG.md`).

## Work order
Follow the plan's critical path. Do these **in order**, respecting each task's `Deps:`:

**Phase M1 (beta-safe — do first):**
`A1` and `A2` (parallel, no deps) → `A3` → `A4` → `A5` → `A6` → `A7` → `A8`; then Epic **B** (B1–B3), Epic **C** (C1, C3, C6), Epic **D** (D1, D2), Epic **E** (E1, E2), **F0** (decision — see below), **G1**, and the transaction-row category fix (UX-3). Add **L1** (CI) once a few tasks have landed.

Then Phase M2, then M3 per the plan's "Milestone definitions".

> **Do not start the rest of Epic F (StoreKit) until F0 is decided by the human reviewer.** Implement F0 as a written recommendation in `Docs/Architecture/DECISION_LOG.md` and **stop for sign-off** before F1–F6.

## Per-task protocol
For each task `X`:
1. Open `EXECUTION_PLAN.md`, read task `X` and its source finding in the audit report.
2. Create branch `fix/X-<slug>`.
3. Implement exactly what the task specifies. Open the cited files; verify the current code matches the audit's description before changing it (the audit is from 2026-06-27 — if reality differs, note it and adapt).
4. Add the test named in the task (Swift Testing or XCTest, matching the suite's existing style). Tests live under `VittoraTests/` mirroring the source path.
5. Run the verification command(s) for the task, plus `make build-ios` and `make build-macos`.
6. Update the progress log and open a PR (formats below).
7. Move to the next task. **Do not** wait for review to proceed to an independent next task, but **do** stop if the next task depends on a PR still under review and you're unsure.

## Verification commands
- `make build-ios` · `make build-macos` · `make test`
- Targeted suites: `make test-tax` · `make test-sync` · `make test-data` · `make test-recurring`
- Single suite: `xcodebuild -scheme Vittora -destination 'platform=macOS' -derivedDataPath .build -only-testing:VittoraTests/<Suite> test CODE_SIGNING_ALLOWED=NO`
- Static gates (when a task names one, e.g. "grep returns 0"): run the exact `grep` from the task and paste the result in the PR.

## Definition of Done (per task)
- [ ] Implements the task's steps; acceptance criteria met.
- [ ] New/updated automated test covers each acceptance criterion (mandatory for money/data tasks).
- [ ] `make build-ios` + `make build-macos` succeed; task test command green; no new warnings.
- [ ] No force-unwraps; user-facing strings localized; no new dependencies.
- [ ] Affected docs updated.
- [ ] PR opened + `Docs/Audit/PROGRESS.md` updated.

## Review handoff format (so the reviewer can move fast)
Maintain a running log and write a tight PR per task.

**1) `Docs/Audit/PROGRESS.md`** — append a row per task:
```
| Task | Branch/PR | Status | Tests added | Verify result | Notes/assumptions |
| A2 | fix/A2-transfer-pair-id (#NN) | Ready for review | ModelContainerConfigTests.migrationV1toV2 | build-ios✅ build-macos✅ test-data✅ | Schema V2 lightweight stage; transferPairID optional |
```

**2) PR description template:**
```
## Task <ID> — <title>
Finding: <ID(s)> (see PRELAUNCH_AUDIT_2026-06-27.md)

### What changed
- <bullet per file/area>

### Files
- path/one.swift (+/-)
- ...

### Acceptance criteria — evidence
- [x] <criterion 1> — <how met / test name>
- [x] <criterion 2> — ...

### Tests
- <test file/name>: <what it asserts>
- Result: <paste the relevant pass line(s) / counts>

### Verification
- make build-ios ✅  make build-macos ✅  <task command> ✅
- <static gate output if applicable>

### Deviations / assumptions
- <anything you had to decide; "none" if none>

### Out of scope observed (do NOT fix here)
- <pointers for later, or "none">
```

Keep PRs reviewable (ideally < ~400 changed lines). If a task is genuinely large (e.g. E1 typography across 598 sites, I1 DI refactor, J1/J2), split it into a stacked series `X-part1`, `X-part2`, … each independently green, and say so in the log.

## Stop-and-ask triggers (open a question instead of guessing)
- Any **financial formula** where the correct behavior is ambiguous (rounding mode, tax edge case, split remainder policy).
- Any **schema migration** that can't be expressed additively/lightweight.
- The **F0** monetization decision and anything in Epic F before sign-off.
- The cited code no longer matches the audit and the right fix is unclear.
- A change would require a new dependency, weaken offline-first, or alter the CloudKit sync contract.
For these, leave the branch in progress, write the question in the PR (as Draft) or in `Docs/Audit/PROGRESS.md` under "Blocked", and move to the next independent task.

## First assignment
Start now with **A1** (`LedgerWriteStore` Unit-of-Work) and **A2** (`transferPairID` + Schema V2 migration) — both have no dependencies and unblock the rest of Epic A. Open one PR each, following the protocol above. After A1+A2 are green, proceed A3 → A4 → A5 → A6 → A7 → A8.

Do not deviate from `EXECUTION_PLAN.md` task scope. When in doubt, prefer correctness and a clear question over a guess.
