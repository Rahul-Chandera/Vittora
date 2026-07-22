# O1 — In-app support path + user-controlled diagnostics

**Branch:** `feature/o1-support-and-diagnostics` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (privacy surface) ·
**Parallel-safe:** yes

## Context

We are shipping a public app with **no in-app support path**. Verified:
`support@vittora.app` appears on the website but in **zero** Swift files. A
user who hits a bug has no way to tell us, so our only signal is a one-star
review with no diagnostic detail.

**This task deliberately does NOT add analytics or crash reporting.** Read
this before writing any code:

- Our published privacy policy states *"What we collect: nothing"*, *"no
  server operated by us that receives your data"*, and *"nothing in the app
  phones home about your behaviour"*. Our App Store privacy manifest declares
  zero collected data types and zero tracking domains.
- Apple **already** gives us crash, hang, and energy diagnostics through
  App Store Connect / Xcode Organizer, gathered under the user's own
  "Share With App Developers" consent. Release builds already emit
  `dwarf-with-dsym`, so those reports symbolicate today.

So the automated telemetry we need already exists at zero privacy cost, and
adding an SDK would break a live public commitment. What is missing is the
**user-initiated** path. Build only that.

## Scope

1. **Support entry point in Settings**: "Contact Support" opening a
   pre-filled mail composer to `support@vittora.app`. If no mail account is
   configured, offer copy-to-clipboard instead of failing silently.
2. **Diagnostic summary** the user can review and attach, containing **only**:
   app version and build, OS version, device model, locale, currency code,
   iCloud sync status (enabled/disabled and last sync result), and record
   *counts* (e.g. "142 transactions, 6 accounts").
3. **Show the user the exact payload before sending**, in a scrollable,
   selectable view, with the text "This is everything that will be included."
   Nothing is attached that the user has not seen.
4. **A recent-error log**: the last 50 non-fatal errors the app already logs,
   with timestamp, error type, and the *code path* — never the record's
   contents. Ring buffer in memory plus App Group storage, cleared on demand
   from the same screen.
5. **FAQ / troubleshooting link** to the website support page.

## Non-goals — do NOT build any of these

Third-party analytics or crash SDKs, `MXMetricManager` upload, any network
call that transmits diagnostics, background or automatic sending, a unique
install/device identifier, session or funnel tracking, or a feature-usage
counter. If a task seems to need one, **stop and ask the reviewer.**

## Privacy requirements (Tier A — the whole point of this task)

- **No amount, balance, note, payee, account name, category name, or date of
  any individual transaction may appear in the payload.** Counts only.
- **Nothing leaves the device except through the user's own mail composer,
  which they can edit or cancel.** No `URLSession` in this feature at all.
- **No identifier that persists across installs**, and no
  `identifierForVendor`.
- The Apple **privacy manifest must remain unchanged** — if this feature
  would require a new declared data type, it is out of scope by definition.
  A test must assert the manifest still declares zero collected types.

## Acceptance criteria

- [ ] Unit test asserts the diagnostic payload contains **no** transaction
      amount, note, payee, account name or category name — seed the demo
      dataset, generate the payload, and assert none of those strings appear
      in it. This is the single most important test in the task.
- [ ] Unit test asserts the payload contains no persistent identifier.
- [ ] Test asserting the error log stores the code path but never record
      contents.
- [ ] Test asserting `PrivacyInfo.xcprivacy` still declares zero collected
      data types and zero tracking domains.
- [ ] UI test: Settings → Contact Support → payload preview is visible and
      scrollable before any send action.
- [ ] Graceful path when no mail account is configured.
- [ ] Localized (`en`, `hi`) and passes the P1/A2 accessibility audits.
- [ ] `make build-ios`, `make build-macos`, `make test` green.
- [ ] **Reviewer sign-off posted before merge.**

## Companion work (reviewer, not this agent)

Add to `Docs/Runbooks/RELEASE_CHECKLIST.md`: after each release, review
Xcode Organizer crash/hang reports and App Store Connect Metrics. That is
where our crash signal comes from — no code required.
