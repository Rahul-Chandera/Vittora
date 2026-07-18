# W1 — Widget extension scaffold + shared read-only data access

**Branch:** `feature/w1-widget-scaffold` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (touches store access)

## Context

No widget extension exists yet. Two things make this cheaper than it
looks: the SwiftData store already lives in the App Group container
(`AppGroupConfiguration.identifier = "group.com.enerjiktech.vittora"`,
see `Packages/VittoraCore/.../Foundation/AppGroupConfiguration.swift` and
`ModelContainerConfig`), and `Packages/VittoraCore` was created to be
linked from extension targets (see its Package.swift comment).

## Scope

1. Add a **WidgetKit extension target** `VittoraWidgets` (iOS only for
   now), bundle id `com.enerjiktech.vittora.widgets`, with the App Group
   entitlement (`group.com.enerjiktech.vittora`) and the same deployment
   target as the app (iOS 26).
2. Link `VittoraCore` from the extension. Do NOT link the app target's
   sources.
3. Add a `WidgetDataProvider` in VittoraCore: opens the group-container
   store **read-only** and exposes exactly two queries:
   - `todaySpending() -> (amount: Decimal, currencyCode: String)`
   - `budgetSnapshot() -> (spent: Decimal, total: Decimal, currencyCode: String)`
   (current-month, same definitions the Dashboard uses — reuse the
   existing use cases/repositories where possible rather than
   reimplementing sums).
4. Ship one placeholder widget (static "Vittora" small widget) proving the
   extension builds, installs, and can read a value from the store.
5. Currency formatting must go through `CurrencyDefaults`/existing
   formatters — note `CurrencyDefaults.code` reads the persisted app
   currency; the widget must read the same UserDefaults **via the app
   group suite**, not `.standard` (extension processes have their own
   standard defaults). If the currency key is only in `.standard` today,
   mirror it to the group suite from the app at write time (small change
   in `SettingsViewModel`) — do not move existing storage.

## Non-goals

Real widget designs (W2/W3), interactivity (W4), intents (W5), macOS
widgets.

## Acceptance criteria

- [ ] `make build-ios` builds the app + extension; CI green.
- [ ] Placeholder widget appears in the widget gallery on the iOS
      simulator and renders a value read from the group store.
- [ ] Store is opened read-only from the extension; no migration, no
      writes, no CloudKit sync initiated from the widget process.
- [ ] The app itself launches and syncs exactly as before (regression:
      run the app, add a transaction, verify it appears).
- [ ] Unit tests for `WidgetDataProvider` queries (seeded in-memory
      store: today's spend and budget snapshot match expected values).

## Verification steps (execute, attach evidence to PR)

1. Build & run on iPhone simulator; add the widget from the gallery;
   screenshot it rendering data.
2. Add a transaction in the app; screenshot the widget after timeline
   refresh (or force-refresh) showing the updated value.
3. Run `make test`; paste the summary.
