# App Store Metadata — en-IN (India storefront)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, Live Activities, the interactive widget, Watch voice entry, multi-page scanning, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark).

Paste-ready per field. India uses **en-GB** as its base English variant, so
spelling here is en-GB (organise, colour, personalise) — verify the localization
slot in App Store Connect before pasting.

Price tier stays Free but the app offers in-app purchases from 1.7.0
(DEC-013/014/015); Vittora Pro may now be described. The "no ads, no
trackers, no accounts, no data selling" claims remain true and must be kept.
INR examples and regime language per DEC-010 D5.

**Verified against `develop`:** the compliance tip engine
(`IndiaComplianceTipEngine.swift`) really does cover Section 269ST, Section
40A(3), SFT cash-deposit reporting, the GST registration threshold and Section
194-IB TDS on rent. The India tax estimator really does model 80C, 80CCD (NPS),
80D including parents and senior rates, HRA, the standard deduction, cess and
surcharge. Hindi and Spanish are both in `knownRegions`.

Last refreshed 2026-07-30, replacing text that had described v1.0 and mentioned
neither Hindi nor the India compliance tips — the two strongest India-specific
reasons to download.

---

## App Name (30 max — 25, unchanged)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 29, unchanged — still the sharpest framing for India)

```
Budgets, tax & daily spending
```

## Promotional Text (170 max — 162)

```
New in 1.8: shared household budgets, Live Activities, smarter reports and FY 2026-27 tax rules. Old vs new regime, cash-limit heads-ups. No bank linking, no ads.
```

## Description (4000 max — 3945)

```
Vittora is the personal finance app that never asks for your bank password or OTP.

No bank linking. No account aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced across iPhone, iPad, Apple Watch and Mac, and fully usable offline.

अब हिंदी में — Vittora is fully available in Hindi.

TRACK EVERY RUPEE
• Log expenses, income and transfers in seconds — UPI, card or cash
• Category suggestions that learn from your own history, on your device
• Categories with sub-categories, payees and accounts
• Scan receipts and multi-page documents, and import or export CSV any time

ON YOUR WRIST, HOME SCREEN AND DYNAMIC ISLAND
• Apple Watch: log an expense with the Digital Crown, or just say "500 for groceries"
• An interactive widget logs a preset expense without opening the app
• Live Activities: a running total while you shop, and a countdown to your next bill
• Home Screen, Lock Screen and StandBy widgets; amounts hidden while locked

INDIA TAX, WORKED OUT FOR YOU
• Old regime vs new regime, side by side, with FY 2026-27 rules
• 80C, NPS under 80CCD(1B) and employer NPS under 80CCD(2), 80D including parents and senior rates, HRA, the standard deduction, cess and surcharge with marginal relief
• Also estimates tax for the US, UK, Canada and Australia

CASH-LIMIT HEADS-UPS
• A quiet heads-up when an entry crosses a limit worth knowing about — cash receipts under Section 269ST, cash business expenses under 40A(3), large cash deposits that get reported, the GST registration threshold, and TDS on rent under Section 194-IB
• Informational only and dismissible. Vittora does not file anything and does not give tax advice

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Colour-coded warnings before you overspend, not after
• Household sharing: share budgets with family or flatmates through iCloud, by member, and choose who can edit

SAVINGS GOALS AND SINKING FUNDS
• Set a target and watch the progress ring fill
• Several goals can share one account; Vittora warns when they claim more than it holds

REPORTS THAT EXPLAIN YOUR MONEY
• Financial health score, and a spending outlook with what-if scenarios
• Net worth over time, cash flow forecast and an annual summary
• A plain-language month summary by Apple Intelligence, on supported devices
• Unusual-spending alerts and budget suggestions from your own records
• Category breakdown, 50/30/20, emergency fund tracker and subscription audit
• Custom reports, and monthly and annual PDF export

YOUR YEAR IN REVIEW
• Total spent, top categories, biggest month, top payees and milestones
• Share it as an image — amounts are left out by default

SPLIT & SETTLE
• Track money lent and borrowed, and split group expenses with friends and flatmates

RECURRING, HANDLED
• Salary, rent, subscriptions — set once, logged on schedule, with reminders and quiet hours

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• Face ID / Touch ID app lock
• No ads, no trackers, no analytics resold to anyone
• In-app support: you see the whole diagnostic summary first, and it never includes your amounts, notes or payees
• Delete all your data at any time

Vittora is free to use, on every device.

Your records, your splits, household sharing, iCloud sync and CSV export stay free, always. Vittora Pro is an optional upgrade that unlocks the forward-looking analysis: tax estimates and regime comparison, the financial health score, spending outlook, cash flow forecast, subscription audit, the 50/30/20 report, the emergency fund tracker, custom reports with PDF export, and unlimited receipt scanning. Without Pro you get five receipt scans a month; everything you created stays yours.

Vittora Pro is available monthly, yearly with a 7-day free trial, or as a one-time Lifetime purchase.

Requires iOS 26, iPadOS 26 or macOS 26.
```

## Keywords (100 max — 93, deliberately not at the limit)

```
budget,expense tracker,money manager,spending,savings,tax,regime,80C,UPI,GST,personal finance
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Use the English section of `WHATS_NEW_1.8.0.md`.

## Category / Age Rating (unchanged)

- Primary: Finance, Secondary: Productivity
- 4+

---

## Notes for whoever publishes this

- **The compliance-tip section is the single most valuable addition here** and
  nothing comparable exists in competing India expense trackers. It is also the
  section most likely to draw App Review attention, which is why the second
  bullet states plainly that Vittora files nothing and gives no tax advice. Do
  not trim that disclaimer to save characters.
- **The Devanagari line is deliberate** — one short sentence, immediately after
  the privacy hook, where a Hindi-speaking browser will see it without scrolling.
  It is a single line so the listing stays readable for English-first users.
  Remove it if App Store Connect flags mixed-script Description content, which it
  has not historically.
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): iphone-69-in / iphone-65-in / ipad-13-in / watch-in (English, $) or the -hi sets (Hindi, ₹). Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
- "Top payees" replaces en-US's "top merchants" — payee is the term the app uses
  in English throughout, and merchant reads as US retail.
