# App Review Information — Notes field (Guideline 2.1 response)

Paste into **App Store Connect → App Review Information → Notes** for both
the iOS and macOS submissions (same underlying app, same answers — only
item 2 below differs per platform). Apple's request had 7 items; items are
numbered to match.

---

## 1. Screen recording

*(Capture this yourself on a physical device — see the shot lists below, not
paste-able text.)*

**Record separately per platform, not once for both.** iOS and macOS are
separate submissions in App Store Connect, each with its own Review
Information/attachment slot — a reviewer evaluating the Mac binary only
sees what's attached to that submission. The Mac UI is also a genuinely
different shell (`SidebarNavigation` + `HSplitView` panes, not a tab bar),
so an iPhone recording doesn't stand in for it.

Vittora has no account registration/login, no paid/subscription flow (the
app is 100% free at launch, no IAP), no user-generated content shared with
other users, and no runtime permission prompts other than the three listed
in item 5. So each recording only needs to cover the core flow:

### iOS/iPadOS recording

1. Launch the app (fresh install or existing data — either is fine, no
   login screen will appear).
2. If this is a fresh install: complete onboarding (enter a name, pick a
   currency) — this is stored locally only, not an account.
3. Dashboard: show the spending/income/budget overview.
4. Add a transaction via Quick Actions (Expense or Income) — show the
   category picker.
5. Transactions list: show search/filter.
6. Budgets: open a budget, show spent/remaining.
7. Savings goals: open a goal, show progress.
8. Reports: open Category Breakdown or Monthly Overview.
9. Settings → Currency (show the picker) and Settings → App Lock (show the
   Face ID/Touch ID toggle — this is where the Face ID prompt in item 1's
   checklist applies).
10. Add Transaction → attach receipt → camera opens (VisionKit document
    scanner) — this is where the camera prompt applies.

### macOS recording

Same flow, adapted for the Mac shell — **skip the camera step**: receipt
scanning is gated `#if os(iOS)` in `ReceiptScannerView.swift` and doesn't
exist on Mac at all.

1. Launch → Dashboard (sidebar navigation visible).
2. Add a transaction via Quick Actions.
3. Transactions → click a row, show the split-view detail pane populate.
4. Budgets → open one, show spent/remaining.
5. Savings goal → show progress.
6. Reports → Category Breakdown.
7. Settings → Currency picker.
8. Settings → App Lock toggle (Touch ID prompt if this Mac has one paired;
   otherwise just showing the toggle is fine).
9. Payees → Import from Contacts (this feature does work on Mac, unlike
   the camera scan) — this is where the Contacts prompt applies.

No account deletion flow to show beyond Settings → Data → Delete All Data,
which is worth including on either platform since it's a distinctive
privacy feature.

---

## 2. Devices and OS tested on

*(Fill in with your actual hardware — template below. Apple wants physical
devices, not only Simulator.)*

**iOS/iPadOS submission**, e.g.:
- iPhone 17 Pro Max, iOS 26.x (physical device)
- iPad Pro 13" (M5), iPadOS 26.x (physical device)
- [add any other physical devices you tested on]

**macOS submission**, e.g.:
- MacBook Pro / Mac mini / iMac [model], macOS 26.x (Apple Silicon)

If your only physical-device testing was on a subset of these and the rest
was Simulator, list the physical devices you actually have and note that
additional configurations were verified via Xcode Simulator.

---

## 3. App purpose and target audience

Vittora is a personal finance tracking app for iPhone, iPad, and Mac. It
helps individuals and households track income and expenses, manage
category budgets, save toward goals, split shared expenses, track informal
debts (money lent or borrowed between individuals), and get a lightweight
income-tax estimate (U.S. federal or India old-vs-new-regime, depending on
the user's region).

The target audience is salaried individuals, freelancers, and households in
the U.S. and India who want manual, privacy-first expense tracking without
linking a bank account or handing financial data to a third-party
aggregator. The problem it solves: most finance apps require bank-account
linking through a data aggregator (Plaid-style) or upload data to a vendor
cloud; Vittora works fully offline with data stored on-device and,
optionally, synced only through the user's own private iCloud account —
never through any server we operate.

---

## 4. Setup and access instructions

**No login, no account, no demo credentials are needed or exist.** Vittora
has no user accounts, no sign-up, and no authentication server. On first
launch, the user completes a short local onboarding (enter a display name,
choose a currency) and lands directly in the app with an empty state.

To see the app populated rather than empty, add a few transactions using
the "+" Quick Action on the Dashboard (Expense/Income/Transfer), or create
a Budget/Savings Goal from their respective tabs — all data entry is
immediate, no setup wizard or external file required.

The only optional gate is App Lock (Face ID/Touch ID), which is **off by
default** — reviewers will not be blocked by it unless they explicitly
enable it in Settings.

---

## 5. External services, tools, or platforms

Vittora uses **only first-party Apple frameworks** — no third-party SDKs,
analytics, ad networks, or backend servers of any kind:

- **iCloud (CloudKit)** — optional private-database sync between a user's
  own devices, via `NSPersistentCloudKitContainer`. Off by default from the
  app's perspective in the sense that it syncs only the signed-in user's
  own iCloud account; never a server we control.
- **VisionKit** (`VNDocumentCameraViewController`) — on-device document
  scanning for attaching a receipt photo to a transaction. No image or
  extracted text is sent anywhere; it stays in the local transaction
  record (and the user's iCloud, if sync is enabled).
- **Contacts framework** — optional, user-initiated import of an existing
  contact's name/photo to label a Payee or Debt record. Nothing is sent to
  us; contact data is copied locally into that Payee/Debt entity.
- **LocalAuthentication (Face ID / Touch ID)** — optional App Lock; the app
  only receives a pass/fail result from the OS, never biometric data.

No payment processor is integrated (the app is free, no in-app purchases
at this time), no data providers, and no AI/ML services beyond Apple's
on-device VisionKit — no data is sent to any external AI service.

---

## 6. Regional differences

Vittora functions identically across all regions for its core features
(transactions, budgets, savings, debts, splits, sync, App Lock). The only
region-aware behavior:

- **Currency**: the user picks a currency in Settings (USD, INR, EUR, GBP,
  JPY, CAD, AUD, SGD, AED); this only changes formatting/symbols, not
  feature availability.
- **Tax Estimator**: shows a U.S. federal estimate (filing status, standard
  deduction, 401(k)/IRA headroom) or an India old-vs-new-regime comparison,
  depending on which the user selects in their tax profile — both are
  available to any user regardless of App Store storefront; nothing is
  geofenced.

No other content, pricing, or feature differs by region at this time
(initial storefronts: United States, India).

---

## 7. Regulated industry / protected material

Vittora is not a financial institution and does not require special
authorization. It does not connect to bank accounts, does not move money,
does not process payments, and does not provide licensed financial, tax,
legal, or investment advice — this is stated explicitly in the app's Terms
of Service and on the Tax Estimator screen. All calculations (budgets,
tax estimates, reports) are derived solely from data the user manually
enters and are clearly presented as informational tools, not professional
advice. No third-party protected material (financial data feeds, licensed
content, etc.) is used.

---

## After submitting

Paste sections 1–7 above (with the recording uploaded separately and
device list in §2 filled in) into **both** the iOS and macOS app's Review
Information → Notes field before resubmitting. Since both platforms got
the identical templated 2.1 request, the same notes apply to both — no
need to write two different responses.
