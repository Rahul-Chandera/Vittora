# L3 — user-facing strings that never reached the string catalogue — **DONE**

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

## Scope, as measured

Two passes were needed, because the first measurement was wrong in an
instructive way.

**Pass 1 — regex over `String(localized: "…")`: 131 keys.** That is what the
first version of the check counted, and it is an undercount. A regex cannot see
interpolated strings (`String(localized: "Year \(y)")` becomes the key
`Year %@`) and it cannot see bare SwiftUI `Text("literal")`, which SwiftUI also
localizes.

**Pass 2 — the compiler's own `.stringsdata`: 92 further keys.** This is
authoritative: it is exactly what Xcode would write into the catalogue. It
surfaced the format-string accessibility labels, the Watch complication strings,
and one genuine bug the regex could never have found:

> `YearInReviewView` asked for `Year %@` (it interpolated `String(year)` to avoid
> a "Year 2,026" thousands separator) while the catalogue only had `Year %lld`.
> The key never matched, so the year picker fell back to English.

Totals: **185 keys added** — 131 + 54 translated, and 38 marked
`"shouldTranslate": false`.

## What was done

1. **Added and translated 185 keys** into `hi` and `es`, following the
   terminology already in the catalogue rather than inventing new words
   (*बजट*, *बचत*, *कैटेगरी*, *पेयी*, *उधार* / *presupuesto*, *ahorros*,
   *categoría*, *beneficiario*, *deuda*). Accessibility labels follow the
   existing patterns exactly: "Add X" → "X जोड़ें" / "Agregar X",
   "Opens the X form" → "X फ़ॉर्म खोलता है" / "Abre el formulario de X".
2. **Preview and fixture strings were made non-localizable at the source.**
   38 keys came from `#Preview` blocks in the design system and from
   `UITestDataSeeder`. A **Release** build extracts them identically to Debug —
   verified, not assumed — so they really do ship, and nobody should hand a
   translator `ifElse() modifier`.

   The first attempt marked them `"shouldTranslate": false`, which is the String
   Catalog's own mechanism. That failed `SpanishLocalizationCatalogTests`, which
   asserts every entry carries a translation. Per house rule 9 the assertion is
   not the thing to change, so the strings were fixed where they are produced:
   `Text("x")` → `Text(verbatim: "x")`, `String(localized: "x")` → `"x"`, and the
   `Toggle`/`accessibilityValue` overloads that take `LocalizedStringKey` were
   given `Text(verbatim:)` instead. Those keys no longer enter the catalogue at
   all, and both catalogue tests pass unmodified.
3. **Fixed `Accent Colour` → `Accent Color`** in `SettingsSectionViews`. Neither
   spelling was in the catalogue and the app uses US spelling everywhere else.
4. **Every translation is placeholder-checked.** The apply script fails if a
   translation drops, adds, or changes the `%@` / `%lld` sequence, because that
   is a format crash at runtime rather than a cosmetic error.
5. **Rewrote the check to read `.stringsdata`** instead of grepping source, and
   wired it into CI *after* `make build-ios` (it needs a compile to exist).

## A third way strings escaped: platform-conditional code (2026-08-16)

The `.stringsdata` rewrite closed the regex hole but left a structural one. The
gate ran against `.build-ios` only, and a string inside `#if os(macOS)` is never
compiled by the iOS build — so it produces no `.stringsdata` entry and the gate
cannot see it. Not "missed": invisible.

Found when `ShareSheet` gained a macOS text branch. Running the gate against
`.build-macos` reported the two new keys *and* a pre-existing one,
`"Running on macOS"` in a `#Preview`, whose iOS twin two lines above already used
`Text(verbatim:)` while the macOS branch did not.

`DERIVED` now takes a colon-separated list and CI runs
`DERIVED=.build-ios:.build-macos` after **both** builds. Keys are unioned, so a
string only has to be reachable from one platform. A listed path with no
`.stringsdata` is a hard error (exit 2) rather than a silent skip — otherwise a
missing macOS build would turn straight back into a green run.

Confirmed by deleting a macOS-only key from the catalogue: the iOS-only scan
exits 0, the two-build scan exits 1 and names it.

Watch out for: the gate globs *every* `.stringsdata` under each path, including
stale slices from earlier builds. A leftover x86_64 slice once reported two keys
as missing that were in fact already fixed. CI checks out clean, so this only
bites locally.

## Verified

- `Scripts/ci/check-localization-coverage.sh` → 0 missing, 0 untranslated.
- iOS Debug and Release builds succeed with the new catalogue.
- `HindiLocalizationUITests` and `SpanishLocalizationUITests` pass.
- hi and es screenshot sets re-captured: all six slots render fully localized,
  including "वर्ष 2026" / "खर्च का 64%" and "Necesidades / Gustos / Ahorros".

## Acceptance

- [x] `Scripts/ci/check-localization-coverage.sh` exits 0 (now driven by the compiler's `.stringsdata`, not a regex).
- [x] Preview and fixture strings carry `"shouldTranslate": false` rather than being translated.
- [ ] **STILL OPEN:** a Hindi and a Spanish speaker should read the new entries — 185 strings of user-facing product text, authored without native review.
- [x] The script runs in CI / build-and-test, after **both** `make build-ios`
      and `make build-macos`, so `#if os(macOS)` strings are covered.
- [x] hi/es sets fully re-captured and the marketing sets regenerated.
