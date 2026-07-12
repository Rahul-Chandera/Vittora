# M2-T3 — App Store Metadata Packs (en-US · en-GB→India)

**Board draft · 2026-07-02 · for Rahul to review + enter in App Store Connect.**
Executes `M2_GTM_EXECUTION_PLAN.md` §2 under M1/DEC-010 conditions and M2-D1(a).

## Mechanics (read first)
- **Locale mapping:** ASC has **no "English (India)"** locale. The India storefront serves **English (U.K.)** metadata when present → `en-US` = primary + US treatment, **`en-GB` = India treatment** (verify precedence on ASC setup; consider adding Hindi `hi` post-launch).
- **Limits:** name ≤30 · subtitle ≤30 · keywords ≤100 chars (comma-separated, no spaces) · promotional text ≤170 (updatable without review) · description ≤4000.
- **Rules applied:** no word duplicated across name/subtitle/keywords (wasted index); **no competitor trademarks in the keyword field** (guideline 2.3.7 risk — Mint/YNAB appear only as factual CSV-compatibility statements in the description); nothing from the never-claim list (bank sync, widgets, Watch, Siri, filing, real-time collaboration); US tax never the headline + honesty label verbatim; zero-analytics claim featured (M2-D1(a)); OS requirement stated (DEC-009).

---

## 1 · en-US (primary — US treatment)

| Field | Copy | Count |
|---|---|---|
| Name | `Vittora: Private Budget App` | 27/30 |
| Subtitle | `No bank linking. No tracking.` | 29/30 |
| Keywords | `expense,tracker,money,csv,import,finance,privacy,tax,401k,hsa,spending,offline,receipt,scanner,cash` | 99/100 |
| Promotional text | `Private budgeting with zero bank linking and zero analytics. Your data stays on your devices and iCloud. Import Mint or YNAB CSV exports in minutes.` | ~149/170 |

**Description:**

> Your budget is your business. Vittora is a private, offline-first money app: no bank logins, no ads, **no analytics of any kind — not even our own**. Your data lives on your devices and in your personal iCloud.
>
> TRACK — Fast transaction entry, receipt scanning (OCR), smart categorization that learns your payees, saved filters, and a full edit history.
> BUDGET — Monthly budgets with real alerts at 75/90/100%, recurring transactions, and cash-flow projection so you can see the months ahead.
> SPLIT — Track group expenses and settle up; share a clean summary or PDF with friends.
> SAVE — Savings goals with monthly plans, plus 401(k), IRA and HSA contribution headroom so you know what room you have left this year.
> IMPORT — Moving from Mint or YNAB? Import your CSV export in minutes. Generic bank CSV works too.
> TAX — A built-in U.S. tax estimate as you go. *Federal estimate — state taxes not included.*
> PROTECT — Face ID app lock, encryption, and offline-first storage with optional iCloud sync.
>
> PRIVACY, FOR REAL
> No account required. No bank linking. No tracking, no third-party SDKs, no analytics. If you delete the app and your iCloud data, we couldn't recover it — because we never had it.
>
> Tax figures are estimates for planning only — not tax, legal, or investment advice.
>
> REQUIREMENTS
> iPhone or iPad with iOS 26 or later · Mac with macOS 26 or later · Optional sync uses your Apple ID and iCloud.

**What's New (1.0):** `Welcome to Vittora 1.0 — private budgeting with budgets & alerts, splits, receipt scanning, CSV import, savings headroom, and a federal tax estimate. Everything stays on your devices and your iCloud.`

**Screenshot script (order · overlay caption):**
1. Dashboard ($) · *"Your money, entirely private"*
2. Budget list w/ threshold alert · *"Budgets that actually alert you"*
3. CSV import flow (Mint/YNAB profile picker) · *"Bring your Mint or YNAB history"*
4. Tax summary **with the federal honesty label visible** · *"Know your federal estimate"*
5. Savings goal + 401(k)/HSA headroom · *"See your contribution headroom"*
6. App-lock / privacy screen · *"No bank logins. No analytics."*

---

## 2 · en-GB (→ India storefront treatment)

| Field | Copy | Count |
|---|---|---|
| Name | `Vittora: Money & Tax Tracker` | 28/30 |
| Subtitle | `Budgets, splits & 80C planning` | 30/30 |
| Keywords | `income,calculator,expense,hra,regime,salary,bills,savings,privacy,rupee,offline,receipt,scanner,emi` | 99/100 |
| Promotional text | `Compare old vs new regime, track 80C & HRA headroom, split group expenses — private by design. No SMS reading, no bank linking, no analytics.` | ~141/170 |

**Description:**

> The money app that actually understands Indian taxes. Vittora combines everyday expense tracking with year-round tax planning — privately, on your own device.
>
> PLAN YOUR TAX, ALL YEAR
> • Old vs new regime comparison with FY-aware slabs
> • Section 80C, 80D, 80CCD(1B) and HRA tracking with statutory caps
> • Surcharge and marginal relief handled correctly
> • See remaining 80C/80D headroom before March, not after
>
> TRACK & BUDGET — Fast entry in ₹ (lakh/crore aware), receipt scanning, smart categorization, monthly budgets with real alerts, recurring transactions, EMIs and debts, savings goals, cash-flow projection.
> SPLIT WITH FRIENDS — Track group expenses, settle up, and share a clean summary or PDF.
> PRIVATE BY DESIGN — No SMS reading. No bank linking. No account signup. **No analytics of any kind.** Face ID app lock and encryption; your data stays on your device and your personal iCloud.
>
> Tax figures are estimates for planning only — verify before filing; not tax, legal, or investment advice.
>
> REQUIREMENTS
> iPhone or iPad with iOS 26 or later · Mac with macOS 26 or later · Optional sync uses your Apple ID and iCloud.

**What's New (1.0):** `Namaste, Vittora 1.0 — regime-aware tax estimates with 80C/80D/HRA planning, budgets & alerts, splits, receipt scanning and CSV import. Private by design: no SMS reading, no analytics.`

**Screenshot script (order · overlay caption):**
1. Dashboard (₹, lakh-formatted) · *"Every rupee, privately tracked"*
2. Regime comparison screen · *"Old vs new regime, instantly"*
3. 80C/80D/HRA utilization view · *"Fill your 80C before March"*
4. Split summary/share sheet · *"Split trips. Settle up cleanly."*
5. Budget alert notification · *"Budgets that warn you in time"*
6. Privacy/app-lock screen · *"No SMS reading. No analytics."*

---

## 3 · Compliance cross-check (both locales)
- ✅ Every claimed feature verified shipped (`M2 §1`); nothing from the never-claim list
- ✅ US honesty label verbatim in description **and** shown in screenshot #4 (M1 condition #1)
- ✅ Zero-analytics claim consistent with privacy manifest + M2-D1(a) (no telemetry exists — verified)
- ✅ OS/device requirements stated (DEC-009)
- ✅ Estimate disclaimers present (both) — matches in-app `TaxDisclaimer`
- ✅ Competitor names out of keyword fields (2.3.7); factual CSV compatibility only in descriptions
- ⬜ Rahul: verify en-GB→India storefront precedence in ASC when creating the localization
- ⬜ Rahul: privacy nutrition label answers = "Data Not Collected" (consistent with zero-telemetry reality)
