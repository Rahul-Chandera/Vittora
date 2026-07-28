# L2 — Spanish (es) localization

**Branch:** `feature/l2-spanish-localization` · **PR into:** `develop` ·
**Review tier: B** · **Parallel-safe:** yes (with W1)

## Context

Plan M3.7.2. The United States is our primary market, and Spanish is its
second language — roughly 13% of US households speak it at home. This is the
highest-reach localization available to us, and the expensive part is
already built: L1 (Hindi) established the entire display-time localization
architecture in 1.3. This task reuses it rather than inventing anything.

## Reuse — read these before writing code

- `Vittora/Localizable.xcstrings` — the string catalogue. `hi` is already a
  complete second language; `es` follows exactly the same shape.
- `knownRegions` in `Vittora.xcodeproj/project.pbxproj` — currently
  `(en, hi, Base)`. Add `es`.
- `CategoryEntity.displayName(locale:bundle:)` — **already** localizes
  default category names at display time while user-created names stay
  untouched. Add `es` cases; do **not** redesign this.
- `VittoraUITests/HindiLocalizationUITests.swift` — the model for the new
  Spanish UI test.

## Scope

1. Add `es` to `knownRegions` and provide `es` translations for **every**
   string in `Localizable.xcstrings`, including the strings added by 1.4
   (H1 Handoff activity titles, C1 India compliance tips, O1 Contact
   Support / diagnostics).
2. Add `es` cases to the default-category display-name mapping.
3. Localize the Watch app, widgets, and App Intents / Siri phrases — these
   are separate string tables; L1 covered them and `es` must match.
4. Verify layout at Spanish string lengths. Spanish runs roughly 15–25%
   longer than English; the usual casualties are buttons, tab labels, and
   table headers.

## Translation quality bar

- **Financial terminology must be correct, not literal.** "Balance" is
  *saldo*, not *balance*; "Budget" is *presupuesto*; "Savings goal" is
  *meta de ahorro*; "Net worth" is *patrimonio neto*; "Debt" is *deuda*.
  A mistranslated finance term destroys trust faster than an untranslated
  string.
- Use **neutral Latin American Spanish** (our US Hispanic audience is
  predominantly of Latin American origin), not peninsular. Prefer *ustedes*
  over *vosotros*.
- Keep the app's existing voice: plain, calm, non-imperative.
- **Do not translate**: the app name "Vittora", user-created category and
  payee names, or currency codes.

## Non-goals

Spanish-language App Store metadata (separate marketing task), a
Spain/Latin-America tax regime, right-to-left support, and any new feature.

## Acceptance criteria

- [ ] Every string in `Localizable.xcstrings` has an `es` translation —
      a test or script asserts **zero** missing `es` entries, so a future
      untranslated string fails CI rather than shipping in English.
- [ ] Default categories display in Spanish; a user-created category named
      e.g. "Gym" stays "Gym".
- [ ] **Locale-switch regression test**: seed in `en`, switch to `es`, seed
      again → no duplicate categories, IDs unchanged, names follow the new
      locale. (This is the L1 × FIX-A interaction; it must hold for `es`
      too.)
- [ ] `VittoraUITests/SpanishLocalizationUITests.swift` walks the core
      flows in `es`, asserting **Spanish labels** — locate controls by their
      Spanish text where that is the coverage, not only by accessibility
      identifier. (A2 regressed exactly this in the Hindi suite; don't
      repeat it.)
- [ ] The P1/A2 accessibility audits still pass with `es` active, including
      at accessibility Dynamic Type sizes — longer Spanish strings are a
      realistic clipping risk.
- [ ] Watch, widgets, and Siri phrases localized.
- [ ] `make build-ios`, `make build-macos`, `make test` green.
