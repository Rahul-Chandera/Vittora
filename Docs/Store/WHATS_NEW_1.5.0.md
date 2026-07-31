# What's New — 1.5.0

App Store "What's New in This Version" copy.

Unlike 1.4.0 — which had to cover everything since launch because 1.1–1.3 were
never published — this is a **normal incremental release**, so the copy is
short. Users are coming from 1.4.0.

1.4.1 was folded into this release rather than shipped separately, so the
accessibility work appears here.

Verified against `develop`: Spanish is in `knownRegions`, `YearInReviewMath`
ships, and Year in Review has no iOS-only gating (its single `#if os(iOS)` is a
cosmetic navigation-title modifier), so **both features ship on iOS and Mac**.

---

## iOS / iPadOS (≈900 characters)

```
YEAR IN REVIEW
• See your year in one place: total spent, top categories, biggest month, top
  merchants, savings, and a few milestones
• Share it as an image — amounts are left out by default, so you can post it
  without posting your finances
• Pick any year you have records for

ESPAÑOL
• Vittora is now fully available in Spanish

हिंदी AND ESPAÑOL, PROPERLY
• Reports, budgeting tools and settings that were still showing English now
  appear in your language — including 50/30/20, the emergency fund tracker,
  quiet hours and appearance

ACCESSIBILITY
• Section headings across the app are clearer and easier to read
• Better colour contrast for amounts and labels
• Continued VoiceOver and Dynamic Type improvements

Still no accounts, no ads, no tracking — your data stays on your devices.
```

---

## Mac (≈850 characters)

Same two features; no Watch or widget claims, and "share" is worded for the
Mac share sheet.

```
YEAR IN REVIEW
• See your year in one place: total spent, top categories, biggest month, top
  merchants, savings, and a few milestones
• Save or share it as an image — amounts are left out by default, so you can
  post it without posting your finances
• Pick any year you have records for

ESPAÑOL
• Vittora is now fully available in Spanish

हिंदी AND ESPAÑOL, PROPERLY
• Reports, budgeting tools and settings that were still showing English now
  appear in your language

ACCESSIBILITY
• Section headings across the app are clearer and easier to read
• Better colour contrast for amounts and labels
• Continued VoiceOver improvements

Still no accounts, no ads, no tracking — your data stays on your devices.
```

---

## Notes for whoever publishes this

- **The privacy line on sharing is the point of the Year in Review section.**
  "Amounts are left out by default" is a real product decision, not marketing —
  the include-amounts toggle ships off, with a test asserting it.
- **The accessibility bullets are genuine user-facing fixes for anyone on
  1.4.0**, not internal cleanup: 38 Form section headers rendered as low-contrast
  grey, and one amount colour sat at 4.55:1. Both are fixed here.
- **Do not list** the "Year 2,026" year-picker bug, the two texts hidden from
  VoiceOver, or the missing chart axis. All three were inside Year in Review,
  which is new in this release — no shipped user ever saw them.
- **Do not mention** the eight skipped audits or the CI runtime work. Internal.
- **The localization line is for existing users, not new ones.** Anyone already
  on 1.4.0 with the device language set to Hindi has been looking at English
  50/30/20, emergency fund, quiet hours and appearance screens since 1.4.0
  shipped. That is a visible fix they will notice, which is why it earns its own
  section rather than being folded into "Español". Spanish users never saw the
  broken state — es only shipped in this release — but the same strings were
  missing for them, so one section covers both.
- The Spanish listing itself (es-US metadata, screenshots) is separate marketing
  work and is **not** covered by this release-notes text.
