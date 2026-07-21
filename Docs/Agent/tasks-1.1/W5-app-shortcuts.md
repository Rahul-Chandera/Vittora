# W5 — App Shortcuts: spending query + add-expense phrase

**Branch:** `feature/w5-app-shortcuts` · **PR into:** `develop` ·
**Review tier: B** (post-merge review) · **Depends on:** W1 + W4 merged

## Scope

First App Intents integration (none exists today):

1. **`GetTodaySpendingIntent`** — returns a spoken/displayed summary:
   "You've spent $132.50 today." Reads via `WidgetDataProvider` (W1).
   Runs in-process without opening the app.
2. **`AddExpenseIntent`** — opens the app into QuickEntry (reuse W4's
   deep-link destination via `openAppWhenRun = true`). Do NOT write
   transactions headlessly in 1.1 — entry needs category/account choices
   the intent can't collect well yet.
3. An `AppShortcutsProvider` with phrases:
   - "How much did I spend today in ${applicationName}"
   - "Add an expense in ${applicationName}"
   Localize phrase strings per house rules.
4. Respect App Lock: `GetTodaySpendingIntent` must NOT return amounts
   while App Lock is enabled and the app is locked — return "Unlock
   Vittora to see your spending" instead. (Financial data must not leak
   through Siri around the lock.)

## Non-goals

Parameterized add ("add 500 for groceries") — deferred until entry
without opening the app is designed properly; budget-remaining query;
Watch.

## Acceptance criteria

- [ ] Both shortcuts appear in the Shortcuts app under Vittora.
- [ ] Running the spending query returns the correct amount for the demo
      dataset, formatted in the app's currency.
- [ ] With App Lock enabled + locked, the query returns the unlock
      message, never an amount (unit-test this gate).
- [ ] Add-expense shortcut opens QuickEntry.
- [ ] `make test` green.

## Verification steps

1. Screenshots: shortcuts listed in the Shortcuts app; query result tile
   showing the amount.
2. App Lock on → run query → screenshot of the refusal message.
3. `make test` summary.
