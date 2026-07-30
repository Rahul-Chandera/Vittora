# Real-device test checklist

Run before every App Store submission, on a physical iPhone signed into a real
iCloud account. The simulator cannot exercise iCloud sync, biometrics,
Handoff, notifications, or widgets truthfully.

**Test the build you intend to submit.** Not a rebuild, not a sibling branch —
the same archive that goes to App Store Connect.

## 0. Setup

- [ ] Delete any existing Vittora install first, so seeding runs fresh
- [ ] Device signed into iCloud with iCloud Drive on
- [ ] A second device (iPad or Mac) signed into the **same** iCloud account,
      for sync and Handoff checks

## 1. The three bugs found on 1.0 — must pass

These shipped in 1.0. If any regress, do not submit.

- [ ] **Account delete.** Accounts → an account **with transactions** → delete.
      Expect a clear, *visible* message that it must be archived instead — the
      error must not be hidden behind the floating tab bar. Then delete an
      account **with no transactions** → it deletes.
- [ ] **Duplicate categories.** Delete the app, reinstall, open it. Repeat
      three times. Category list must be identical every time — no duplicates.
- [ ] **Picker labels.** New Recurring → set Account, Category, Payee. Each
      picker must show the **selected item's name**, never the word
      "Selected". Repeat on Transaction form, Budget form, Split forms.

## 2. Money correctness

- [ ] Add transactions in several categories; dashboard total equals the sum
      of the rows shown, to the paisa/cent
- [ ] Budget remaining = budget − spent, matching the transaction list
- [ ] A recurring rule's monthly and annual figures agree with each other
- [ ] Switch currency in Settings → every screen re-renders in the new symbol

## 3. iCloud sync

- [ ] Add a transaction on device A → appears on device B
- [ ] Edit it on B → the edit lands on A
- [ ] Delete on A → gone on B
- [ ] Airplane mode → add records → re-enable → they sync without duplicates

## 4. Security

- [ ] Enable App Lock. Background and reopen → Face ID prompts, and no
      redaction box or stray lines appear over the authentication UI
- [ ] Cancel Face ID → fallback to passcode works
- [ ] With App Lock on, invoke a Siri Shortcut → must **not** bypass the lock

## 5. Widgets and Watch

- [ ] Home Screen widget shows real figures and refreshes after a new entry
- [ ] **Lock the device.** Lock Screen widget and Watch complication redact
      amounts, and VoiceOver announces the redacted label — not the number
- [ ] Unlocked, VoiceOver on the same widget **does** read the amount
- [ ] Watch quick entry: crown changes the amount and VoiceOver announces each
      change

## 6. Accessibility

- [ ] VoiceOver through Dashboard, Transactions, Budgets, Reports, Settings —
      every control has a meaningful label
- [ ] Largest accessibility Dynamic Type size: no clipped or truncated text
- [ ] OLED black theme: text remains legible on every screen

## 7. Localization

- [ ] Switch device language to Hindi → app is in Hindi, no English strings
      left in the main flows
- [ ] Default category names follow the language
- [ ] **Switch back to English → still no duplicate categories** (this is the
      canonical-name fix; a duplicate set here is a release blocker)

## 8. 1.4 features — only if shipping 1.4

- [ ] **Handoff:** open Transactions on iPhone → the Vittora icon appears in
      the Mac Dock / iPad App Switcher → continuing lands on the same screen
      with the same filter. Repeat for transaction detail, budget detail,
      report detail, account detail
- [ ] **Handoff draft:** start typing a transaction on iPhone without saving →
      continue on Mac → every field carried over
- [ ] **Handoff after sign-out:** sign out of iCloud → advertising stops
- [ ] **India compliance tips:** set country India, record a cash receipt of
      ₹2,00,000 → §269ST tip appears. ₹1,99,999.99 → no tip. Dismiss a tip →
      it stays dismissed after relaunch
- [ ] **Contact Support:** Settings → Contact Support → the diagnostic payload
      is shown in full and is scrollable **before** anything is sent. Read it:
      it must contain no amount, note, payee, account or category name. Verify
      Copy Diagnostics works with no mail account configured

## 9. Store readiness

- [ ] App icon correct on Home Screen and in Settings
- [ ] No placeholder or lorem text on any screen
- [ ] Support and privacy links open the live pages
