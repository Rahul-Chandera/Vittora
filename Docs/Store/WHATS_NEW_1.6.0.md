# What's New — 1.6.0

App Store "What's New in This Version" copy.

> **Written after the fact.** 1.6.0 was released on 2026-09-08 before this file
> existed — an earlier draft was lost before it was ever committed. The copy
> below is reconstructed from the 106 commits in `v1.5.0..v1.6.0`. **Check it
> against what was actually entered in App Store Connect** rather than assuming
> the two match; if they differ, the store copy is the truth and this file
> should be corrected to it.

1.6.0 is a **fix-and-polish release**, not a feature release. There is no new
headline feature, so the copy leads with the crash and data-correctness fixes,
which are what a 1.5.0 user actually notices. Users are coming from 1.5.0.

The Mac copy is longer than iOS because most of the release *is* Mac work —
roughly forty commits of macOS UI correction.

---

## iOS / iPadOS (809 characters)

```
FIXES
• Fixed a crash that could happen on launch or while syncing when two records
  ended up sharing an identifier
• Fixed a crash when tapping a slice of the spending donut in Reports
• New accounts no longer take an opening balance of zero when you left the
  field blank

YOUR MONEY, ADDED UP CORRECTLY
• Net worth, the cash flow forecast and the emergency fund tracker now total
  each currency separately instead of mixing them into one figure

NOTHING DELETED BY ACCIDENT
• Transactions, budgets, savings goals, accounts and group expenses now ask
  before they are deleted
• Settling or deleting a shared group expense is reachable again

QUICKER ENTRY
• The keyboard now opens on the amount field when you add a transaction

Still no accounts, no ads, no tracking — your data stays on your devices.
```

---

## Mac (1,072 characters)

Same fixes, plus the macOS interface work, which is the bulk of this release.

```
FIXES
• Fixed a crash that could happen on launch or while syncing when two records
  ended up sharing an identifier
• Fixed a crash when tapping a slice of the spending donut in Reports
• New accounts no longer take an opening balance of zero when you left the
  field blank

YOUR MONEY, ADDED UP CORRECTLY
• Net worth, the cash flow forecast and the emergency fund tracker now total
  each currency separately instead of mixing them into one figure

NOTHING DELETED BY ACCIDENT
• Transactions, budgets, savings goals, accounts and group expenses now ask
  before they are deleted
• Settling or deleting a shared group expense is reachable again

A TIDIER MAC APP
• Save and Cancel now look and behave the same in every dialog, and stay
  disabled until the form is complete
• Text fields show a cursor again
• The category and payee pickers open at a usable size, with aligned icons
• Sharing opens the Mac share menu directly
• The dashboard has consistent spacing and clearer section headings

Still no accounts, no ads, no tracking — your data stays on your devices.
```

---

## Notes for whoever publishes this

- **Lead with the crashes, not the Mac polish.** The duplicate-identifier crash
  was reproducible on a real iPhone, and the donut crash fired on an ordinary
  tap in Reports. Those are the two things a 1.5.0 user may actually have hit.
- **The delete confirmations are a safety fix, not a feature.** Nine destructive
  deletes had no confirmation before this release. Worth its own section because
  a user who lost data to one will recognise it.
- **The currency wording matters.** The old behaviour did not mislabel the
  total — it summed different currencies into a single number. "Totals each
  currency separately" is the accurate description; avoid "converts", because
  nothing is converted.
- **Do not list** the store-screenshot work, the CI or accessibility-audit work,
  or the watch gallery fixes. All internal.
- **Do not claim new Watch or widget functionality.** Neither changed in a
  user-visible way this release.
- The opening-balance bug was a factor-of-ten error in a specific path, not a
  general arithmetic fault. The bullet above is deliberately narrow — do not
  broaden it into "fixed incorrect balances".

## Related

- `Docs/Store/WHATS_NEW_1.5.0.md` — previous release
- `Vittora/Resources/AppStoreMetadata/whats-new.txt` — **stale**, still reads
  "Version 0.1.0" and describes pre-1.0 content. It was not updated for 1.4.0,
  1.5.0 or 1.6.0; either bring it in line with this file or delete it, because
  right now it is a trap for anyone who reads it as current.
