# FIX-B — Account delete appears to do nothing + pickers show "Selected"

**Branch:** `fix/delete-feedback-and-picker-labels` · **PR into:** `develop` ·
**Review tier: B**

Two defects reported from a real iPhone on 1.0.

---

## Bug 1 — Deleting an account appears to do nothing

### Root cause (already diagnosed)

Deletion is **intentionally blocked** for accounts that have
transactions — `DeleteAccountUseCase.delete` throws
`validationFailed("Cannot delete account with transactions. Archive it
instead.")`. The view model catches it into `vm.error`, and
`AccountListView` renders that in an `.overlay { VStack { Spacer(); … } }`
— i.e. pinned to the **bottom of the screen, underneath the floating tab
bar**, where the user never sees it. From the user's side: they confirm
"Delete" and nothing happens.

### Required fix

1. **Surface the failure where the user is looking.** Replace the
   bottom-pinned toast with the app's standard error presentation
   (`.errorAlert(message:)` is already used elsewhere — reuse it, don't
   invent a new pattern).
2. **Make the message actionable.** The app is telling the user "archive
   it instead" — so offer that: the alert should have an **"Archive
   Instead"** action that performs the archive, plus Cancel. Blocking a
   destructive action is fine; a dead end is not.
3. Audit the **other list screens** that use the same bottom-overlay
   error pattern (grep for `.overlay {` + `vm.error`) and fix any that
   are similarly hidden behind the tab bar. Same bug, other screens.

### Why our tests missed it

Use-case tests assert that `delete` **throws** for an account with
transactions — correct, and passing. Nothing asserted that the user can
**see** the failure. That is the "test the wiring, not just the pure
function" gap again. The regression test must assert the visible alert,
not the thrown error.

---

## Bug 2 — Pickers display "Selected" instead of the chosen item

### Root cause (already diagnosed)

`RecurringFormView` lines ~116, ~151, ~186 render a literal placeholder:

```swift
if viewModel.selectedAccountID != nil {
    Text(String(localized: "Selected"))   // ← never shows the actual name
}
```

The view knows only the ID and never resolves it to a name. Same pattern
for Category and Payee.

### Required fix

1. Resolve the selected entity and display its **name** (with its icon
   where the design already shows one, matching how
   `TransactionFormView` presents the same pickers — reuse that
   presentation rather than writing a third variant).
2. **Check every other picker for the same defect.** The user explicitly
   asked for this. At minimum audit the pickers backed by:
   `DebtFormViewModel`, `TransactionFormViewModel`,
   `TransactionCSVImportViewModel`, `CategorizationRulesViewModel`,
   `RecurringFormViewModel`. Fix each that shows a placeholder instead
   of the selected value, and list in the PR which ones you checked and
   what you found — including the ones that were already correct.
3. Keep the empty state ("Select account…") for when nothing is chosen.

### Why our tests missed it

No test asserted picker **label content** — tests set and read IDs, which
stayed green while the UI showed a meaningless word.

---

## Acceptance criteria

- [ ] Deleting an account with transactions shows a visible alert with an
      **Archive Instead** action that works; deleting an account with no
      transactions still deletes.
- [ ] UI test asserting the **alert is visible** after a blocked delete
      (not merely that the use case throws).
- [ ] Recurring form shows the real account/category/payee names.
- [ ] Every picker audited; PR lists each one checked and its result.
- [ ] Test asserting a picker label shows the selected entity's name.
- [ ] Screenshots: blocked-delete alert, and the recurring form with all
      three pickers populated.
- [ ] `make test` green.
