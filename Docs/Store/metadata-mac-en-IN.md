# App Store Metadata — macOS platform tab, en-IN (India storefront)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark). **Mac:** Live Activities, the interactive widget, Watch voice entry and multi-page scanning are iOS-only and are not claimed; household invitations can only be accepted on iPhone or iPad (`HouseholdShareAcceptance.swift` is `#if os(iOS)`), which the copy says.

The macOS tab for the India storefront. `metadata-mac-en-US.md` is the same tab
for en-US; `metadata-en-IN.md` is the **iOS/iPadOS** tab for India. All three
are separate fields in App Store Connect.

India uses **en-GB** as its base English variant, so spelling here is en-GB
(organise, colour, personalise) — matching `metadata-en-IN.md`.

Price tier stays Free but the app offers in-app purchases from 1.7.0
(DEC-013/014/015); Vittora Pro may now be described. The "no ads, no
trackers, no accounts, no data selling" claims remain true and must be kept.

**What the Mac build must NOT claim** (same target audit as
`metadata-mac-en-US.md`, re-verified against `project.pbxproj`): the Apple Watch
app, complications, Smart Stack, Home Screen / Lock Screen / StandBy widgets, or
camera receipt scanning — `ReceiptScannerView` gates `VisionKit` behind
`#if os(iOS)` and the Mac gets a file-import fallback instead.

**What it may claim, verified present and unguarded on macOS:** the India tax
estimator and compliance tips (`IndiaComplianceTipEngine.swift` and the Tax
feature are in the main target; their only `#if os(iOS)` blocks are
`navigationBarTitleDisplayMode` and `keyboardType`, both cosmetic), Siri /
Shortcuts, Handoff, Spotlight, PDF export, every report, Year in Review, and
full keyboard navigation.

---

## App Name (30 max — 25, same record as iOS)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 30)

```
Budgets, tax & spending on Mac
```

## Promotional Text (170 max — 157)

```
New in 1.8: shared household budgets, smarter reports and FY 2026-27 tax rules on your Mac. Old vs new regime, cash-limit heads-ups. No bank linking, no ads.
```

## Description (4000 max — 3924)

```
Vittora is the personal finance app that never asks for your bank password or OTP.

No bank linking. No account aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced with your iPhone and iPad, and fully usable offline.

अब हिंदी में — Vittora is fully available in Hindi.

BUILT FOR THE MAC
• Full keyboard navigation — move through every screen and form without touching the mouse
• A real Mac window, sized the way you want it, not a stretched phone app
• Touch ID or your password to unlock the app
• Import and export CSV, and attach receipts and documents from Finder

TRACK EVERY RUPEE
• Log expenses, income and transfers in seconds — UPI, card or cash
• Category suggestions that learn from your own history, on your device
• Categories with sub-categories, payees and accounts
• Search and filter your full history instantly

INDIA TAX, WORKED OUT FOR YOU
• Old regime vs new regime, side by side, with FY 2026-27 rules
• 80C, NPS under 80CCD(1B) and employer NPS under 80CCD(2), 80D including parents and senior rates, HRA, the standard deduction, cess and surcharge with marginal relief
• Heads-ups on the rules that catch people out — Section 269ST cash limits, Section 40A(3), cash-deposit reporting, the GST registration threshold and Section 194-IB TDS on rent. Informational only; Vittora files nothing and gives no tax advice
• Also estimates tax for the US, UK, Canada and Australia

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Colour-coded warnings before you overspend, not after
• Household sharing: shared budgets through iCloud, spending by member, and control over who can edit (invitations are accepted on iPhone or iPad)

SAVINGS GOALS AND SINKING FUNDS
• Set a target, track contributions, watch the progress ring fill
• Several goals can share one account; Vittora warns when they claim more than it holds

REPORTS THAT EXPLAIN YOUR MONEY
• Financial health score, and a spending outlook with what-if scenarios
• Net worth over time, cash flow forecast and an annual summary
• Monthly overview with a plain-language summary, written by Apple Intelligence on supported Macs
• Unusual-spending alerts and budget suggestions from your own records
• Category breakdown, 50/30/20, emergency fund tracker and subscription audit
• Custom reports, and monthly and annual PDF export

YOUR YEAR IN REVIEW
• Total spent, top categories, biggest month, top payees and milestones
• Share it as an image — amounts are left out by default

CONTINUE ANYWHERE
• Handoff from iPhone, Spotlight search, and Siri for what you've spent or a new expense

SPLIT & SETTLE
• Track money lent and borrowed, and split group expenses with friends and flatmates

RECURRING, HANDLED
• Salary, rent, subscriptions — set once, logged on schedule, with reminders and quiet hours

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• No ads, no trackers, no analytics sold to anyone
• In-app support: you see the whole diagnostic summary first, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free to use, on every device.

Your records, your splits, household sharing, iCloud sync and CSV export stay free, always. Vittora Pro is an optional upgrade that unlocks the forward-looking analysis: tax estimates and regime comparison, the financial health score, spending outlook, cash flow forecast, subscription audit, the 50/30/20 report, the emergency fund tracker, custom reports with PDF export, and unlimited receipt scanning. Without Pro you get five receipt scans a month, and everything you have already created stays yours.

Vittora Pro is available monthly, yearly with a 7-day free trial, or as a one-time Lifetime purchase.

Requires macOS 26. Also available for iPhone, iPad and Apple Watch.
```

## Keywords (100 max)

```
budget,expense tracker,money manager,spending,savings,personal finance,tax,80c,income tax,receipts
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Use the English section of `WHATS_NEW_1.8.0.md`, without its "ON IPHONE AND APPLE WATCH" section (iPhone-only features).

---

## Notes for whoever publishes this

- **The India tax content is the reason this file exists.** The generic
  `metadata-mac-en-US.md` has none of it, and the tax estimator plus compliance
  tips are the strongest India-specific reason to download on any platform.
- **The closing line does the cross-sell.** Naming iPhone, iPad and Apple Watch
  recovers the Watch story without claiming it runs on the Mac — this is a
  universal purchase, so a Mac buyer already owns the iOS app.
- Touch ID wording says "or your password" deliberately: plenty of Macs have no
  Touch ID sensor, and `LocalAuthentication` falls back to the password there.
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): mac-in (English, $) or mac-hi (Hindi, ₹). Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
