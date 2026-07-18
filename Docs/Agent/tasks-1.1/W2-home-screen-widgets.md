# W2 — Home Screen widgets: Today's Spending + Budget Remaining

**Branch:** `feature/w2-home-widgets` · **PR into:** `develop` ·
**Review tier: B** (post-merge review) · **Depends on:** W1 merged

## Scope

Replace the W1 placeholder with two real widgets, matching the app's
design system (VColors/VTypography equivalents; widgets can't import the
app target, so put shared tokens needed by widgets into VittoraCore or
mirror minimally):

1. **Today's Spending** — small + medium. Small: today's total spent +
   currency, subtle up/down vs yesterday. Medium: adds a 7-day mini bar
   sparkline.
2. **Budget Remaining** — small + medium. Small: overall monthly budget
   progress ring + remaining amount. Medium: top 3 budget categories with
   per-category progress bars (reuse the spent/remaining semantics from
   `BudgetListViewModel` — overall = sum(spent)/sum(amount)).
3. Timeline policy: refresh `.atEnd` with entries for midnight boundary
   (today's spend resets); call `WidgetCenter.reloadAllTimelines()` from
   the app after transaction/budget mutations (single hook where
   `AppState.notifyChanged` fires — keep it to one line per change type).
4. Light + dark appearance; placeholder/redacted states for the gallery.
5. Empty states: no budgets → "Set a budget" prompt; no transactions →
   zero, not blank.

## Non-goals

Lock Screen families (W3), interactivity (W4), configuration intents.

## Acceptance criteria

- [ ] Both widgets render in small + medium, light + dark, on iPhone
      simulator; gallery previews look correct (redacted placeholders).
- [ ] Adding a transaction in the app updates the widgets after reload.
- [ ] Currency symbol matches the app's Settings currency (regression:
      switch currency in Settings, reload, widget follows).
- [ ] Midnight rollover entry exists in the timeline (unit-test the
      timeline provider's entry dates around a fixed "now").
- [ ] No writes to the store from the widget process.

## Verification steps

1. Screenshots: both widgets × both sizes × light/dark (8 total) on the
   simulator, with the US demo dataset (`--ui-test-seed-demo`).
2. Change currency in Settings → reload widgets → screenshot showing the
   new symbol.
3. `make test` summary in the PR.
