# FIX-A — Duplicate default categories after reinstall

**Branch:** `fix/duplicate-default-categories` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (data integrity)

Reported from a real iPhone on 1.0: reinstalling the app several times
produces multiple copies of every default category (three "Groceries",
three "Dining", …).

## Root cause (already diagnosed — do not re-investigate)

`DefaultDataSeeder.seedDefaultCategoriesIfNeeded()` gates on a
**UserDefaults flag** (`com.vittora.defaultDataSeeded`):

```swift
guard !userDefaults.bool(forKey: seededKey) else { return }
```

Uninstalling the app **wipes UserDefaults**, but the user's categories
still exist in **their CloudKit private database**. So on reinstall:
flag is absent → a fresh set of defaults is seeded → CloudKit syncs the
original set back down → duplicates. Every reinstall adds another set.

The flag is the wrong source of truth: it records "did *this install*
seed?" when the question is "does *this account's data* already contain
defaults?"

## Required fix

1. **Gate on the data, not on a flag.** Before seeding, check whether
   default categories already exist (they are marked `isDefault: true`)
   and seed only what is genuinely missing. Keep the UserDefaults flag
   only as a cheap fast-path if you wish, but it must never be the sole
   authority.
2. **Seeding must be idempotent by identity.** Give default categories a
   **deterministic, stable identity** (e.g. a UUID derived from a fixed
   namespace + the category's canonical name) so the same default seeded
   on two devices/installs is *the same record*, and CloudKit merges it
   rather than duplicating. This is the durable fix — a
   "does-it-exist" name check alone still races with a slow CloudKit
   sync that lands after seeding.
3. **Clean up users who already have duplicates.** A one-time
   deduplication for defaults: keep the earliest record per canonical
   default, and **re-point transactions/budgets/recurring rules that
   reference a discarded duplicate** to the survivor before deleting it.
   Losing a category reference on a transaction is not acceptable — no
   transaction may end up orphaned or silently uncategorized.
4. Do not change user-created categories in any way. Only records with
   `isDefault == true` are in scope.

## Why our tests missed it (address this too)

Existing tests run against a **fresh in-memory store with a clean
UserDefaults**, so the gate always looked correct. Nothing simulated
"data already present but flag absent" — which is exactly the reinstall
state. Add that as an explicit test case.

## Acceptance criteria

- [ ] Seeding twice against a store that already has defaults produces
      **no duplicates** (test: seed → clear the UserDefaults flag → seed
      again → count unchanged). This reproduces the reinstall bug.
- [ ] Seeding into a store with a *partial* default set adds only the
      missing ones.
- [ ] Deterministic identity: seeding the same default twice yields the
      same category ID (test it).
- [ ] Dedup migration: a store seeded with duplicates collapses to one
      per default, **and** a transaction that referenced a removed
      duplicate now references the survivor (assert the transaction's
      `categoryID`, not just the category count).
- [ ] User-created categories with the same name as a default are left
      untouched.
- [ ] Factory reset + `reseedDefaultCategories()` still works.
- [ ] `make test` green.
- [ ] **Reviewer sign-off before merge.**
