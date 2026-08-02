# App Store Metadata — macOS platform tab, en-IN (India storefront)

The macOS tab for the India storefront. `metadata-mac-en-US.md` is the same tab
for en-US; `metadata-en-IN.md` is the **iOS/iPadOS** tab for India. All three
are separate fields in App Store Connect.

India uses **en-GB** as its base English variant, so spelling here is en-GB
(organise, colour, personalise) — matching `metadata-en-IN.md`.

Free, no IAP (DEC-008). Pro is DEC-011 and must not appear.

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

## Promotional Text (170 max)

```
Now with Year in Review and Hindi. Track spending, budgets and tax on your Mac — old vs new regime, cash-limit heads-ups, no bank linking and no ads. Syncs via iCloud.
```

## Description (4000 max)

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
• Log expenses, income and transfers in seconds
• Organise with categories, payees, accounts and payment methods — UPI, card or cash
• Search and filter your full history instantly
• Your data is yours — export it any time, in a format you can actually read

INDIA TAX, WORKED OUT FOR YOU
• Compare the old and new regimes side by side before you choose
• 80C, 80CCD (NPS), 80D including parents and senior rates, HRA and the standard deduction
• Cess and surcharge included, so the number you see is the number you pay
• Heads-ups on the rules that catch people out — Section 269ST cash limits, Section 40A(3), cash-deposit reporting, the GST registration threshold and Section 194-IB TDS on rent

CONTINUE ANYWHERE
• Handoff — start a transaction on iPhone and finish it on your Mac
• Find any transaction through Spotlight
• Ask Siri what you've spent, or add an expense by voice

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Overall and per-budget progress at a glance
• Colour-coded warnings before you overspend, not after

SAVINGS GOALS
• Set a target, track contributions, watch the progress ring fill
• Emergency fund, a wedding, a new bike — as many goals as you need

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

SPLIT & SETTLE
• Track money you've lent or borrowed with a simple debt ledger
• Split group expenses and see who owes whom

RECURRING, HANDLED
• Salary, rent, subscriptions — set them once and Vittora logs them on schedule
• Upcoming view shows what's about to hit your accounts
• Choose when reminders arrive, with quiet hours

YOURS TO SHAPE
• English, Hindi and Spanish
• True-black theme and a choice of accent colours
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• No ads, no trackers, no analytics sold to anyone
• Contact support from inside the app — you see the whole diagnostic summary before anything is sent, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free. Every feature, every device.

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

Use the **Mac** block in `WHATS_NEW_1.5.0.md`. It already drops the Watch and
widget claims and words sharing for the Mac share sheet.

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
- Mac screenshots for this storefront are `Docs/Store/screenshots/marketing/mac-in/`
  (1440×900, INR amounts). Regenerate with
  `Scripts/store/capture_mac_screenshots.sh mac-in en en_IN IN`, which needs an
  unlocked screen and a signed build.
