# L3 — 131 user-facing strings never reached the string catalogue

**Found:** 2026-07-30, while regenerating store screenshots (PR #173). The Hindi
50/30/20 screen rendered "Needs", "Wants" and "This is a general guideline, not
financial advice." in English under a Hindi headline.

**Severity:** shipped. G1 (50/30/20), G2 (Emergency Fund), N1 (quiet hours) and
T1 (appearance) all went out in **1.4.0, live on the App Store**, so Hindi users
see those screens in English today. W1 (Year in Review) is on `develop` for 1.5
and has the same problem.

## The trap

`SWIFT_EMIT_LOC_STRINGS = YES` is already set on every shipping target
(`VittoraTests`/`VittoraUITests` are `NO`, correctly). Extraction is not
disabled. The catch:

> **Only Xcode's IDE writes the extracted strings back into
> `Localizable.xcstrings`. `xcodebuild` does not.**

So a feature developed and merged without anyone opening the project in Xcode
ships with its strings missing from the catalogue. And because the catalogue
reports **1314/1314 keys translated in both hi and es**, every dashboard says
localization is complete. The gap is invisible from the inside — it is an
*extraction* gap, not a translation gap.

This is also why the working tree on `release/1.4.0` carried ~67 uncommitted
catalogue additions: someone opened Xcode, the IDE extracted, and the result was
never committed.

## Scope

`Scripts/ci/check-localization-coverage.sh` (added in this PR) reports it:

```
catalogue keys                 : 1314
interpolated literals (skipped): 143
literals missing from catalogue: 131
keys with no hi translation    : 0
keys with no es translation    : 0
```

Worst files:

| count | file |
|---|---|
| 21 | `Features/Reports/Views/YearInReviewView.swift` |
| 19 | `Features/Reports/Views/EmergencyFundReportView.swift` |
| 16 | `Features/Settings/Views/SettingsSectionViews.swift` |
| 7 | `Features/Reports/Views/FiftyThirtyTwentyReportView.swift` |
| 5 each | `SettingsViewModel`, `SavingsGoalFormView`, `ReportsHomeView` |
| 4 | `Components/YearInReviewShareCopy.swift` |
| 3 each | `SavingsGoalListView`, `TaxProfileFormView`, `SplitGroupListView` |

The 143 interpolated literals are reported but never failed on — they become
`%@`/`%lld` keys in the catalogue and cannot be matched against raw source. A
sample of them should still be checked by hand.

## Do this

1. Open `Vittora.xcodeproj` in Xcode and build once. The IDE extracts and writes
   the new keys into `Localizable.xcstrings`. **Commit that file** — that step is
   the one that has been missed every time.
2. Translate the new entries into `hi` and `es`. Follow the terminology already
   in the catalogue rather than inventing new words — the app is consistent today
   and should stay that way (*बजट*, *बचत दर*, *presupuesto*, *meta de ahorro*).
3. **Triage before translating.** Several extracted strings should not be in a
   shipped catalogue at all, and translating them would cement the mistake:
   - `UI Test Merchant`, `UI Test Subscription` — demo fixtures from
     `UITestDataSeeder`, which lives in the app target and therefore extracts.
     Move them out of `String(localized:)`; they are never shown to a user.
   - `72%` — a hardcoded literal in a preview.
   - `Vittora Notification`, `Scheduled delivery verified.` — notification
     verification strings; confirm whether a user ever sees them.
   - `%@ %@` — a bare concatenation. Whatever composes it should build an
     accessibility label properly instead of localizing a joiner.
   - `Accent Colour` — en-GB spelling, while the catalogue uses `Accent Color`.
     One of the two is a typo; do not translate both.
4. Wire the script into CI as a required step of **CI / build-and-test** once it
   passes. It is deliberately *not* wired up in this PR — a check that fails the
   moment it lands would redden `develop` in the middle of the 1.5.0 cut.

## Blocked on this

- `Docs/Store/screenshots/iphone-69-hi` and `iphone-69-es` slots 04–06 are
  mixed-language and must not be published. Slots 01–03 are clean.
- "Vittora is now fully available in Spanish" in `WHATS_NEW_1.5.0.md`, and
  "अब हिंदी में — Vittora is fully available in Hindi" in
  `metadata-en-IN-refresh.md`, are **not accurate** until this lands. Either fix
  this first or soften both lines before submitting.

## Acceptance

- [ ] `Scripts/ci/check-localization-coverage.sh` exits 0.
- [ ] The triaged strings above are removed from `String(localized:)` rather than
      translated.
- [ ] A Hindi and a Spanish speaker have read the new entries — this is 131
      strings of user-facing product text, not internal copy.
- [ ] The script is a required CI step, so this cannot silently recur.
- [ ] hi/es screenshot slots 04–06 re-captured with
      `Scripts/store/capture_screenshots.sh` and the marketing sets regenerated.
