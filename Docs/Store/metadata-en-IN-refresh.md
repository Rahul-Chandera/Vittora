# App Store Metadata — en-IN REFRESH (India storefront)

`metadata-en-IN.md` was written for v1.0 and is stale in exactly the way en-US
was: no Watch app, no widgets, no Siri, no Spotlight, no Handoff, no 50/30/20 or
emergency fund, no subscription audit, no PDF export, no Year in Review — and,
most costly for this storefront, **no Hindi and no India compliance tips**, both
of which shipped in 1.4.0 and are the two strongest India-specific reasons to
download.

India uses **en-GB** as its base English variant, so spelling here is en-GB
(organise, colour, personalise). Verify the localization slot in App Store
Connect before pasting.

Free, no IAP (DEC-008). Pro is DEC-011 and must not appear. INR examples and
regime language per DEC-010 D5.

**Verified on `develop` before writing:** the compliance tip engine
(`IndiaComplianceTipEngine.swift`) really does cover Section 269ST, Section
40A(3), SFT cash-deposit reporting, the GST registration threshold and Section
194-IB TDS on rent. The India tax estimator really does model 80C, 80CCD (NPS),
80D including parents and senior rates, HRA, the standard deduction, cess and
surcharge. Hindi and Spanish are both in `knownRegions`.

---

## App Name (30 max — 25, unchanged)

```
Vittora: Personal Finance
```

## Subtitle (30 max — 29, unchanged — still the sharpest framing for India)

```
Budgets, tax & daily spending
```

## Promotional Text (170 max — 167)

```
Now in Hindi, with Year in Review and an Apple Watch app. Track spending and budgets, compare old vs new regime, and get cash-limit heads-ups. No bank linking, no ads.
```

## Description (4000 max)

```
Vittora is the personal finance app that never asks for your bank password or OTP.

No bank linking. No account aggregators reading your statements. You enter what you spend, and everything stays in your private iCloud — encrypted, synced across iPhone, iPad, Apple Watch and Mac, and fully usable offline.

अब हिंदी में — Vittora is fully available in Hindi.

TRACK EVERY RUPEE
• Log expenses, income and transfers in seconds with quick actions
• Organise with categories, payees, accounts and payment methods — UPI, card or cash
• Search and filter your full history instantly
• Scan receipts, attach documents, and import or export CSV any time — it's your data

ON YOUR WRIST AND YOUR HOME SCREEN
• A full Apple Watch app — log an expense in seconds with the Digital Crown
• Complications and Smart Stack widgets for today's spending and budget left
• Home Screen, Lock Screen and StandBy widgets
• Amounts stay hidden while your device is locked
• Ask Siri what you've spent, or add an expense by voice
• Find any transaction through Spotlight

INDIA TAX ESTIMATOR
• Instant income tax estimate from your salary and deductions
• Old regime vs new regime comparison, so you pick the one that saves more
• Covers 80C, NPS under 80CCD, 80D health cover including parents, HRA, the standard deduction, cess and surcharge

CASH-LIMIT HEADS-UPS
• A quiet heads-up when an entry crosses a limit worth knowing about — cash receipts under Section 269ST, cash business expenses under 40A(3), large cash deposits that get reported, the GST registration threshold, and TDS on rent under Section 194-IB
• Informational only, based on what you have entered, and dismissible. Vittora does not file anything and does not give tax advice

BUDGETS THAT KEEP UP
• Weekly, monthly, quarterly or yearly budgets per category
• Overall progress plus per-budget spent and remaining, at a glance
• Colour-coded warnings before you overspend, not after

SAVINGS GOALS
• Set a target, track contributions, watch the progress ring fill
• Emergency fund, Goa trip, new bike — as many goals as you need

REPORTS THAT EXPLAIN YOUR MONEY
• Monthly overview of income vs expenses across 12 months
• Category breakdown with percentages
• 50/30/20 needs, wants and savings analysis
• Emergency fund tracker — how many months you could cover
• Subscription audit — what your recurring charges really cost
• Cash flow forecast, net worth, annual summary and custom reports
• Export monthly and annual reports as PDF

YOUR YEAR IN REVIEW
• See your whole year: total spent, top categories, biggest month, top payees, savings and milestones
• Share it as an image — amounts are left out by default, so you can post it without posting your finances

SPLIT & SETTLE
• Track money you've lent or borrowed with a simple debt ledger
• Split group expenses with friends and flatmates and see who owes whom

RECURRING, HANDLED
• Salary, rent, subscriptions — set them once and Vittora logs them on schedule
• Upcoming view shows what's about to hit your accounts
• Choose when reminders arrive, with quiet hours

CONTINUE ANYWHERE
• Handoff — start a transaction on iPhone and finish it on iPad or Mac
• Full keyboard navigation on iPad and Mac

YOURS TO SHAPE
• Hindi, English and Spanish
• True-black OLED theme and a choice of accent colours
• Extensive VoiceOver, Dynamic Type and contrast work throughout

PRIVATE BY DESIGN
• Works fully offline; sync is optional and goes only through your personal iCloud
• Face ID / Touch ID app lock
• No ads, no trackers, no analytics resold to anyone
• Contact support from inside the app — you see the whole diagnostic summary before anything is sent, and it never includes your amounts, notes or payees
• Delete all your data at any time, on your terms

Vittora is free. Every feature, every device.

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

Use `WHATS_NEW_1.5.0.md`. Note that the Hindi and compliance-tip work landed in
**1.4.0**, not 1.5 — it belongs in this persistent Description, not in the 1.5
release notes.

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
- **`Docs/Store/metadata-en-IN.md` should be replaced by this file**, not kept
  alongside it. I left the original untouched so you can diff first.
- **Screenshots are captured and current.** Two sets suit this storefront:
  `screenshots/marketing/iphone-69-hi` (Hindi UI, ₹ amounts) and
  `iphone-69-in` (English UI, ₹ amounts). The Hindi set is the stronger choice
  now that Hindi genuinely ships end to end — the earlier mixed-language screens
  were fixed in the L3 localization work. Regenerate either with
  `Scripts/store/capture_screenshots.sh` and `make_marketing.py`.
  Note the demo dataset's payee names and notes are still English ("Lunch Order",
  "Monthly Staples"); that is user data rather than UI strings, but Hindi ones
  would read better in a Hindi gallery.
- "Top payees" replaces en-US's "top merchants" — payee is the term the app uses
  in English throughout, and merchant reads as US retail.
