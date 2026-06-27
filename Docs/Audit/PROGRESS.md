# Audit Remediation Progress

One row per task. See `EXECUTION_PLAN.md` for task definitions and `CURSOR_HANDOFF.md` for the working agreement.

> Branching note: per the current working instruction, task branches are cut off `refactoring` (not `develop`). Never commit directly to `refactoring`/`develop`/`main`.

| Task | Branch/PR | Status | Tests added | Verify result | Notes/assumptions |
|------|-----------|--------|-------------|---------------|-------------------|
| A1 | fix/A1-ledger-write-store | Ready for review | LedgerWriteStoreTests (4 cases: one-save, rollback, recovery, seeded-stub) | build-ios✅ build-macos✅ test-data✅ LedgerWriteStoreTests✅ | `@ModelActor LedgerWriteStore` with `commit(_:)` Unit-of-Work (one `save()`, `rollback()` on failure) + `saveCount` test hook. Operation entry points (`performTransfer/Add/Settle/Delete`) seeded as stubs that throw `LedgerWriteError.notImplemented`; bodies land in A3/A4/A6. Registered in `DependencyContainer`. |
