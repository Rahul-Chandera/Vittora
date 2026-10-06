# App Store Metadata — macOS platform tab (en-US)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark). **Mac:** Live Activities, the interactive widget, Watch voice entry and multi-page scanning are iOS-only and are not claimed; household invitations can only be accepted on iPhone or iPad (`HouseholdShareAcceptance.swift` is `#if os(iOS)`), which the copy says.

Vittora is one App Store record (`id6762046016`) with a **separate metadata tab
per platform**. This file is the macOS tab. `metadata-en-US.md` is the
iOS/iPadOS tab. They must differ, because the Mac build genuinely ships less.

**Verified against `project.pbxproj`, not assumed:**

| Target | Platforms | On Mac? |
|---|---|---|
| `Vittora` | `iphoneos iphonesimulator macosx` | yes |
| `VittoraWidgets` | `iphoneos iphonesimulator` | **no** |
| `VittoraWatch` | `watchos watchsimulator` | **no** |
| `VittoraWatchWidgets` | `watchos watchsimulator` | **no** |

So the Mac copy must **not** claim: the Apple Watch app, complications, Smart
Stack, Home Screen / Lock Screen / StandBy widgets, or camera receipt scanning
(`ReceiptScannerView` gates `VisionKit` behind `#if os(iOS)`; Mac gets a
file-import fallback instead).

It **may** claim, all confirmed present and unguarded on macOS: Siri /
Shortcuts (`Vittora/App/Intents/`, main target), Handoff
(`Vittora/App/AppHandoff.swift`, main target), Spotlight (guarded by
`canImport(CoreSpotlight)`, which succeeds on macOS), PDF export
(`ReportPDFShareLink` has a real `#if os(macOS)` branch), every report, Year in
Review, and full keyboard navigation.

Price tier stays Free but the app offers in-app purchases from 1.7.0
(DEC-013/014/015); Vittora Pro may now be described. The "no ads, no
trackers, no accounts, no data selling" claims remain true and must be kept.

---

## App Name (30 max — 25, same record as iOS)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 25)

```
Private money on your Mac
```

## Promotional Text (170 max — 151)

```
New in 1.8: tax estimates for five countries, shared household budgets and smarter reports on your Mac. No bank linking, no ads, and no data ever sold.
```

## Description (4000 max — 3948)

```
Vittora is the personal finance app that never asks for your bank password.

No bank linking. No Plaid. No third-party aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced with your iPhone and iPad, and fully usable offline.

BUILT FOR THE MAC
• Full keyboard navigation — move through every screen and form without touching the mouse
• A real Mac window, sized the way you want it, not a stretched phone app
• Touch ID or your password to unlock the app
• Import and export CSV, and attach receipts and documents from Finder

TRACK EVERY DOLLAR
• Log expenses, income and transfers in seconds
• Category suggestions that learn from your own history, on your device
• Categories with sub-categories, payees, accounts and payment methods
• Search and filter your full history instantly

CONTINUE ANYWHERE
• Handoff — start a transaction on iPhone and finish it on your Mac
• Find any transaction through Spotlight
• Ask Siri what you've spent, or add an expense by voice

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Color-coded warnings before you overspend, not after
• Household sharing: shared budgets through iCloud, spending by member, and control over who can edit (invitations are accepted on iPhone or iPad)

SAVINGS GOALS AND SINKING FUNDS
• Set a target, track contributions, watch the progress ring fill
• Several goals can share one account, and Vittora tells you when they claim more than it holds

REPORTS THAT EXPLAIN YOUR MONEY
• Financial health score, and a spending outlook with what-if scenarios
• Net worth over time, cash-flow forecast and an annual summary
• Monthly overview with a plain-language summary, written by Apple Intelligence on supported Macs
• Unusual-spending alerts and budget suggestions, based only on your own records
• Category breakdown, 50/30/20, emergency fund tracker and subscription audit
• Custom reports, and monthly and annual PDF export

YOUR YEAR IN REVIEW
• Total spent, top categories, biggest month, top merchants and milestones
• Share it as an image — amounts are left out by default

TAX ESTIMATES FOR FIVE COUNTRIES
• United States, United Kingdom, Canada (all provinces and territories), Australia and India
• See your 401(k), IRA and HSA headroom for the year
• Educational estimates, calculated on your Mac

SPLIT & SETTLE
• Track money you've lent or borrowed with a simple debt ledger
• Split group expenses and see who owes whom

RECURRING, HANDLED
• Salary, rent, subscriptions — set them once and Vittora logs them on schedule
• An Upcoming view, and reminders with quiet hours

YOURS TO SHAPE
• English, Spanish and Hindi
• True-black theme and a choice of accent colors
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• No ads, no trackers, no analytics sold to anyone
• Contact support from inside the app — you see the whole diagnostic summary first, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free to use, on every device. No ads, no trackers, no account, and nothing about you sold to anyone.

Your records, your splits, household sharing, iCloud sync and CSV export stay free, always. Vittora Pro is an optional upgrade that unlocks the forward-looking analysis: tax estimates and regime comparison, the financial health score, spending outlook, cash-flow forecast, subscription audit, the 50/30/20 report, the emergency fund tracker, custom reports with PDF export, and unlimited receipt scanning. Without Pro you get five receipt scans a month, and everything you have already created stays yours.

Vittora Pro is available monthly, yearly with a 7-day free trial, or as a one-time Lifetime purchase.

Requires macOS 26. Also available for iPhone, iPad and Apple Watch.
```

## Keywords (100 max — 94)

```
budget,expense tracker,money manager,spending,savings,personal finance,budget planner,receipts
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Use the English section of `WHATS_NEW_1.8.0.md`, without its "ON IPHONE AND APPLE WATCH" section (iPhone-only features).

---

## Notes for whoever publishes this

- **The closing line does the cross-sell.** Naming iPhone, iPad and Apple Watch
  at the end recovers the Watch story without claiming it runs on the Mac — this
  is a universal purchase, so a Mac buyer already owns the iOS app.
- **"A real Mac window" is a soft claim** and the only line here not tied to a
  specific code path. It is defensible (this is a native SwiftUI build, not Mac
  Catalyst) but trim it if you want the listing to be purely factual.
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): mac. Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
- Touch ID wording says "or your password" deliberately: plenty of Macs have no
  Touch ID sensor, and `LocalAuthentication` falls back to the password there.
