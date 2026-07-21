# L1 — Hindi (hi) localization

**Branch:** `feature/l1-hindi-localization` · **PR into:** `develop` ·
**Review tier: B** (post-merge review)

## Context

Plan M3.7.2. India is a Wave 1 launch storefront and we already ship an
India-specific old-vs-new tax regime comparison — in English only. The
codebase is localization-ready (`String(localized:)` everywhere, a
`Localizable.xcstrings` catalogue), so this is translation and
verification work rather than re-architecture.

## Scope

1. Add **`hi`** to the project's localizations and to
   `Vittora/Localizable.xcstrings`.
2. Translate all user-facing strings. Priority order if the catalogue is
   large: onboarding → dashboard → transaction entry → budgets → savings →
   **tax (India regime screens)** → reports → settings → widgets/watch →
   error and empty states. Do not leave a half-translated core flow.
3. **Financial terminology must be correct, not literal.** Use the terms
   Indian users actually see in banking and tax contexts (e.g. "पुरानी
   कर व्यवस्था" / "नई कर व्यवस्था" for old/new regime, "बजट", "बचत
   लक्ष्य"). Where an English term is the common usage in Indian
   finance, keeping it is better than an unnatural translation — note
   such choices in the PR.
4. **Do not translate**: the app name "Vittora", currency codes, or
   ISO/technical identifiers.
5. Verify layout at Hindi string lengths — Devanagari renders taller and
   many phrases are longer than English. Fix clipping/truncation found in
   the core flows (this is where real bugs hide, not in the translation).
6. Numbers, currency and dates must continue to use the existing
   formatters — **do not** hand-format for Hindi. `hi_IN` grouping
   (1,00,000) comes from the formatter, not from string edits.

## Non-goals

Other languages; RTL support; translating the website; per-string
review by a professional translator (flag anything you are unsure of in
the PR instead of guessing silently).

## Acceptance criteria

- [ ] App runs end-to-end in Hindi (simulator language = Hindi) with no
      untranslated strings in the priority flows listed above.
- [ ] Screenshots of the five core flows + the India tax screens in Hindi,
      showing no clipped or truncated text.
- [ ] Currency renders via the formatter (₹ with Indian grouping), not
      hand-built strings.
- [ ] No `String(localized:)` regressions — every string still goes
      through the catalogue; nothing hardcoded to add a translation.
- [ ] The existing accessibility audit tests still pass (P1's
      `AccessibilityAuditUITests`) — Hindi must not break Dynamic Type or
      contrast fixes.
- [ ] `make test` green.

## Verification steps

1. Run with the simulator set to Hindi; walk the priority flows.
2. Screenshots (gitignored `verification/`, attach to PR — do not commit).
3. Note in the PR any term you were unsure about, so a native reviewer can
   check those specifically rather than re-reading everything.
