# App Store Metadata — en-US (iOS / iPadOS platform tab)

Paste-ready per field. Written against the feature set shipping in **1.5.0** and
verified feature-by-feature against `develop` rather than copied from release
plans.

`metadata-mac-en-US.md` is the macOS tab of the same App Store record; the two
must differ, because the Mac build ships no Watch app and no widgets.

**Binding constraints:** free, no IAP (DEC-008). Pro is DEC-011 and must not
appear here.

Last refreshed 2026-07-30. The previous text had described v1.0.0 for four
releases — no Watch app, widgets, Siri, Spotlight, Handoff, 50/30/20, emergency
fund, subscription audit, cash-flow forecast, PDF export, Year in Review, Hindi
or Spanish.

---

## App Name (30 max — 25, unchanged)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 29)

```
Private money, every device
```

## Promotional Text (170 max — ~166)

```
Now with Year in Review, an Apple Watch app, and Spanish. Track spending, budgets and savings with no bank linking, no ads, and no data ever sold. Private by design.
```

## Description (4000 max)

```
Vittora is the personal finance app that never asks for your bank password.

No bank linking. No Plaid. No third-party aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced across iPhone, iPad, Apple Watch and Mac, and fully usable offline.

TRACK EVERY DOLLAR
• Log expenses, income and transfers in seconds
• Organize with categories, payees, accounts and payment methods
• Search and filter your full history instantly
• Scan receipts, attach documents, and import or export CSV anytime — it's your data

ON YOUR WRIST AND YOUR HOME SCREEN
• A full Apple Watch app — log an expense in seconds with the Digital Crown
• Complications and Smart Stack widgets for today's spending and budget left
• Home Screen, Lock Screen and StandBy widgets
• Amounts are hidden while your device is locked
• Ask Siri what you've spent, or add an expense by voice
• Find any transaction through Spotlight

CONTINUE ANYWHERE
• Handoff — start a transaction on iPhone and finish it on iPad or Mac
• Full keyboard navigation on iPad and Mac

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
• True-black OLED theme and a choice of accent colors
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• Face ID / Touch ID app lock
• No ads, no trackers, no analytics sold to anyone
• Contact support from inside the app — you see the whole diagnostic summary before anything is sent, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free. Every feature, every device.

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

Use `WHATS_NEW_1.5.0.md` — this file covers the persistent Description field,
not the per-version notes.

---

## Notes for whoever publishes this

- **The Mac tab lives in `metadata-mac-en-US.md`** and deliberately drops the
  Watch app, widgets and camera receipt scanning — `VittoraWidgets` and
  `VittoraWatch` exclude `macosx`, and `ReceiptScannerView` gates VisionKit
  behind `#if os(iOS)`. Handoff, Spotlight, Siri/Shortcuts, keyboard navigation,
  every report and Year in Review do ship on Mac and stay.
- **`metadata-en-IN.md` has had the same refresh**, keeping its India tax framing
  and adding the compliance tips shipped in 1.4.0.
- **Screenshots are current.** Every gallery in `screenshots/marketing/` is
  regenerated from the 1.5.0 build — iPhone 6.9"/6.5", iPad, Mac, Watch, plus
  Hindi and Spanish sets. See `screenshots/README.md` to regenerate.
- The support bullet deliberately describes the diagnostic payload's privacy in
  the listing. It is a genuine differentiator and it is literally true — the
  payload is counts-only and shown in full before sending.
