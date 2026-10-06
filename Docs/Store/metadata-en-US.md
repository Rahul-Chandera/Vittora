# App Store Metadata — en-US (iOS / iPadOS platform tab)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, Live Activities, the interactive widget, Watch voice entry, multi-page scanning, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark).

Paste-ready per field. Written against the feature set shipping in **1.8.0** and
verified feature-by-feature against `develop` rather than copied from release
plans.

`metadata-mac-en-US.md` is the macOS tab of the same App Store record; the two
must differ, because the Mac build ships no Watch app and no widgets.

**Binding constraints:** price tier stays Free but the app offers in-app
purchases from 1.7.0 (DEC-013/014/015); Vittora Pro may now be described.
The "no ads, no trackers, no accounts, no data selling" claims remain true
and must be kept.

Previously refreshed 2026-07-30 for 1.5.0.

---

## App Name (30 max — 25, unchanged)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 29)

```
Private money, every device
```

## Promotional Text (170 max — 156)

```
New in 1.8: tax estimates for five countries, shared household budgets, Live Activities and smarter reports. No bank linking, no ads, and no data ever sold.
```

## Description (4000 max — 3874)

```
Vittora is the personal finance app that never asks for your bank password.

No bank linking. No Plaid. No third-party aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced across iPhone, iPad, Apple Watch and Mac, and fully usable offline.

TRACK EVERY DOLLAR
• Log expenses, income and transfers in seconds
• Category suggestions that learn from your own history, on your device
• Categories with sub-categories, payees, accounts and payment methods
• Scan receipts and multi-page documents, and import or export CSV anytime

ON YOUR WRIST, HOME SCREEN AND DYNAMIC ISLAND
• Apple Watch: log an expense with the Digital Crown, or just say "500 for groceries"
• An interactive widget logs a preset expense without opening the app
• Live Activities: a running total while you shop, and a countdown to your next bill
• Home Screen, Lock Screen, StandBy and Smart Stack widgets; amounts hidden while locked
• Siri, Spotlight, Handoff and full keyboard navigation on iPad and Mac

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Warnings before you overspend, not after
• Household sharing: share budgets with the people you live with through iCloud, see spending by member, and choose who can edit

SAVINGS GOALS AND SINKING FUNDS
• Set a target and watch the progress ring fill
• Several goals can share one account, and Vittora tells you when they claim more than it holds

REPORTS THAT EXPLAIN YOUR MONEY
• Financial health score, and a spending outlook with what-if scenarios
• Net worth over time, cash-flow forecast and an annual summary
• Monthly overview with a plain-language summary, written by Apple Intelligence on supported devices
• Unusual-spending alerts and budget suggestions, based only on your own records
• Category breakdown, 50/30/20, emergency fund tracker and subscription audit
• Custom reports, and monthly and annual PDF export

YOUR YEAR IN REVIEW
• Total spent, top categories, biggest month and milestones
• Share it as an image; amounts are left out by default

TAX ESTIMATES FOR FIVE COUNTRIES
• United States, United Kingdom, Canada (all provinces and territories), Australia and India
• See your 401(k), IRA and HSA headroom for the year
• Educational estimates, calculated on your device

SPLIT & SETTLE
• A simple ledger for money you've lent or borrowed
• Split group expenses and see who owes whom

RECURRING, HANDLED
• Salary, rent, subscriptions: set them once and Vittora logs them on schedule
• An Upcoming view, and reminders with quiet hours

YOURS TO SHAPE
• English, Spanish and Hindi
• True-black OLED theme and a choice of accent colors
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• Face ID / Touch ID app lock
• No ads, no trackers, no analytics sold to anyone
• Contact support from inside the app; you see the whole diagnostic summary first, and it never includes your amounts, notes or payees
• Delete all your data at any time

Vittora is free to use, on every device. No ads, no trackers, no account, and nothing about you sold to anyone.

Your records, your splits, household sharing, iCloud sync and CSV export stay free, always. Vittora Pro is an optional upgrade that unlocks the forward-looking analysis: tax estimates and regime comparison, the financial health score, spending outlook, cash-flow forecast, subscription audit, the 50/30/20 report, the emergency fund tracker, custom reports with PDF export, and unlimited receipt scanning. Without Pro you get five receipt scans a month, and everything you have already created stays yours.

Vittora Pro is available monthly, yearly with a 7-day free trial, or as a one-time Lifetime purchase.

Requires iOS 26, iPadOS 26, or macOS 26.
```

## Keywords (100 max — 94, deliberately not at the limit)

```
budget,expense tracker,money manager,spending,savings,personal finance,budget planner,receipts
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Use the English section of `WHATS_NEW_1.8.0.md`.

---

## Notes for whoever publishes this

- **The Mac tab lives in `metadata-mac-en-US.md`** and deliberately drops the
  Watch app, widgets and camera receipt scanning — `VittoraWidgets` and
  `VittoraWatch` exclude `macosx`, and `ReceiptScannerView` gates VisionKit
  behind `#if os(iOS)`. Handoff, Spotlight, Siri/Shortcuts, keyboard navigation,
  every report and Year in Review do ship on Mac and stay.
- **`metadata-en-IN.md` has had the same refresh**, keeping its India tax framing
  and adding the compliance tips shipped in 1.4.0.
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): iphone-69, iphone-65, ipad-13, watch. Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
- The support bullet deliberately describes the diagnostic payload's privacy in
  the listing. It is a genuine differentiator and it is literally true — the
  payload is counts-only and shown in full before sending.
