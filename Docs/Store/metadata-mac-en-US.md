# App Store Metadata — macOS platform tab (en-US)

Vittora is one App Store record (`id6762046016`) with a **separate metadata tab
per platform**. This file is the macOS tab. `metadata-en-US-refresh.md` is the
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

Free, no IAP (DEC-008). Pro is DEC-011 and must not appear.

---

## App Name (30 max — 25, same record as iOS)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 25)

```
Private money on your Mac
```

## Promotional Text (170 max — 155)

```
Now with Year in Review and Spanish. Track spending, budgets and savings on your Mac with no bank linking, no ads, and no data ever sold. Syncs through iCloud.
```

## Description (4000 max)

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
• Organize with categories, payees, accounts and payment methods
• Search and filter your full history instantly
• Your data is yours — export it any time, in a format you can actually read

CONTINUE ANYWHERE
• Handoff — start a transaction on iPhone and finish it on your Mac
• Find any transaction through Spotlight
• Ask Siri what you've spent, or add an expense by voice

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Overall and per-budget progress at a glance
• Color-coded warnings before you overspend, not after

SAVINGS GOALS
• Set a target, track contributions, watch the progress ring fill
• Emergency fund, vacation, new car — as many goals as you need

REPORTS THAT EXPLAIN YOUR MONEY
• Monthly overview of income vs expenses across 12 months
• Category breakdown with percentages
• 50/30/20 needs, wants and savings analysis
• Emergency fund tracker — how many months you could cover
• Subscription audit — what your recurring charges really cost
• Cash-flow forecast, net worth, annual summary and custom reports
• Export monthly and annual reports as PDF

YOUR YEAR IN REVIEW
• See your whole year: total spent, top categories, biggest month, top merchants, savings and milestones
• Share it as an image — amounts are left out by default, so you can post it without posting your finances

US TAX ESTIMATOR
• Instant federal estimate from your income and filing status
• See how much 401(k) and IRA headroom you have left this year

SPLIT & SETTLE
• Track money you've lent or borrowed with a simple debt ledger
• Split group expenses and see who owes whom

RECURRING, HANDLED
• Salary, rent, subscriptions — set them once and Vittora logs them on schedule
• Upcoming view shows what's about to hit your accounts
• Choose when reminders arrive, with quiet hours

YOURS TO SHAPE
• English, Spanish and Hindi
• True-black theme and a choice of accent colors
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• No ads, no trackers, no analytics sold to anyone
• Contact support from inside the app — you see the whole diagnostic summary before anything is sent, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free. Every feature, every device.

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

Use the **Mac** block in `WHATS_NEW_1.5.0.md` — it already drops the Watch and
widget claims and words sharing for the Mac share sheet.

---

## Notes for whoever publishes this

- **The closing line does the cross-sell.** Naming iPhone, iPad and Apple Watch
  at the end recovers the Watch story without claiming it runs on the Mac — this
  is a universal purchase, so a Mac buyer already owns the iOS app.
- **"A real Mac window" is a soft claim** and the only line here not tied to a
  specific code path. It is defensible (this is a native SwiftUI build, not Mac
  Catalyst) but trim it if you want the listing to be purely factual.
- **Mac screenshots are a separate gap** from the iOS ones. The macOS tab needs
  its own set at 2880×1800 or 2560×1600, and the existing captures are iPhone
  frames — they cannot be reused here at all.
- Touch ID wording says "or your password" deliberately: plenty of Macs have no
  Touch ID sensor, and `LocalAuthentication` falls back to the password there.
