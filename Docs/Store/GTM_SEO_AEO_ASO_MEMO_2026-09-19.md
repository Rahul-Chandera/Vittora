# Vittora GTM memo — SEO / AEO / ASO / site growth
**Date:** 2026-09-19  
**Owner:** Grove (GTM) · **Claims:** Priya / FEATURE_STATUS  
**Status:** DRAFT for Rahul approval — do not publish, do not spend, do not create ad accounts  
**Live app:** 1.7.0 only · **1.7.1:** not claimable as live  
**Sources:** https://www.vittora.app + `/Volumes/Data/Projects/Vittora/VittoraWebsite`

---

---

## APPROVED SEQUENCE (Rahul via Mira — 2026-09-20)

Grove does **not** edit site/store. Rahul / Claude Code apply.

**NOW — claim PR only (keep version 1.7.0):**
1. Kill “Saved filters” → “Search & filter”
2. Strip all Vision Pro copy on `/faq` and `/apple-ecosystem`
3. Pro-qualify `/tax-planning` and tax lines on `/features`
4. Rephrase `/features` “households” → personal category budgets only
5. **Net worth:** qualify as **current snapshot** — do **not** remove; no “over time”

**HOLD:** ASO upload, Product Hunt, ads, all 10 new pages (except drafts below), M2.4.

**After claim PR only — next pages (title/outline/content drafts until Priya clears, then Rahul publishes):**
1. `/guides/finance-app-that-doesnt-connect-to-your-bank`
2. `/compare/vittora-vs-ynab`

**GSC:** Rahul creates property on `enerjik.ops`; HTML meta later; no DNS from Grove.

Do not optimize/rank URLs that still contain A/B claim lies until the claim PR is live.


## 1) Website review (growth + crawl)

### Must-fix claims (block rankings that rely on them)

| Claim | Where | Repo | Action |
|--------|--------|------|--------|
| **“Saved filters”** | `/` chip list under Capture | `src/pages/index.astro:45` | **Kill** before any SEO push that repeats homepage copy |
| **“net worth”** as report/framework | `/` reports section | `index.astro:74`, `:119` | **Keep** — qualify as **current snapshot** only; never “over time” |
| **Vision Pro / roadmap** | `/faq` devices answer; `/apple-ecosystem` meta + “Vision Pro (future)” card | `faq.astro:22`, `apple-ecosystem.astro:7,30` | **Kill** — no visionOS target; ASC Compatibility already misleading |
| Version **1.7.0** everywhere | Homepage pill, CTA, JSON-LD `softwareVersion` | `index.astro` + schema | Fine until 1.7.1 ships; then bump site + schema in one release with store |
| Tax features without **Pro** | `/tax-planning`, parts of `/features` | tax-planning page body | Add “with Vittora Pro” — same rule as social bios |
| “budgets across … **households**” | `/features` Plan budgets | features page | Soft risk vs “no household budget sharing” — rephrase to personal category budgets unless Priya clears |

### Per-URL crawl sheet

| URL | Title | H1 | Meta description (summary) | Fix |
|-----|--------|-----|----------------------------|-----|
| `/` | Private Personal Finance for Apple \| Vittora | Know your money. Keep it yours. | Offline-first Apple PF; budgets, reports, receipts, tax, iCloud | Kill Saved filters; qualify net worth as current snapshot; keep privacy FAQ; bump version at 1.7.1 |
| `/features` | Budgets, receipts, reports, and tax tools \| Vittora | Complete personal finance workflow for Apple users | Expense, OCR, budgets, YiR, Watch, tax, iCloud | Pro-qualify tax; avoid households / unshipped |
| `/pricing` | Pricing — free, with an optional Pro upgrade \| Vittora | Free to use. Pro when you want the analysis. | Free + optional Pro; no ads/bank | Strong AEO page — ensure Pro list matches FEATURE_STATUS |
| `/security` | Security without a data business \| Vittora | Security and trust at the core | Offline-first, private iCloud, no data selling | Good; keep aligned with Privacy label “Data Not Collected” |
| `/tax-planning` | Tax planning for India and the U.S. \| Vittora | Tax planning support for India and the U.S. | Educational IN/US planning | **Must** say Pro; not filing software (FAQ already says that) |
| `/apple-ecosystem` | Native on iPhone, iPad, Mac, and Watch \| Vittora | Built for Apple users | Native + widgets/Handoff/Spotlight; **Vision Pro on roadmap** | Strip Vision Pro from meta + body |
| `/download` | Download free on the App Store \| Vittora | Download Vittora | US + India App Store | Fine; deep-link ASC when possible |
| `/faq` | FAQ on privacy, pricing, and devices \| Vittora | Frequently asked questions | Pricing, privacy, devices, tax scope | Kill Vision Pro line; add/strengthen Pro vs free extract; prices OK on FAQ (site) |
| `/privacy` | Privacy Policy \| Vittora | Privacy policy | Device + private iCloud; collect nothing | Fine |
| `/terms` | Terms of Service \| Vittora | Terms of service | License / liability | Fine |
| `/blog` | Guides for private Apple finance \| Vittora | Vittora blog | Expense, budget, privacy, tax IN/US | Index OK; don’t add more generic “how to budget” |

**Blog posts (6) — keep; don’t flood with generic budgeting**

1. `/blog/what-to-look-for-in-a-personal-finance-app-for-apple-devices/`
2. `/blog/how-to-prepare-for-us-tax-season-with-better-transaction-tracking/`
3. `/blog/old-vs-new-tax-regime-in-india-what-to-track-during-the-year/` ← **expand, don’t replace** (see §2)
4. `/blog/how-to-split-household-expenses-without-confusion/`
5. `/blog/why-offline-first-finance-apps-are-better-for-privacy/`
6. `/blog/how-to-track-monthly-expenses-without-spreadsheets/` ← closest to generic; **do not clone**; optional trim later

### Crawl / technical

- `robots.txt`: `Allow: /` + `Sitemap: https://www.vittora.app/sitemap-index.xml` ✓  
- `sitemap.xml` 404; real map is `sitemap-index.xml` → `sitemap-0.xml` (all key URLs present, including `/support/`) ✓  
- **OG image:** every key URL uses the same `https://www.vittora.app/images/og-default.png` — weak for share CTR; not a blocker for crawl, but comparison pages will need unique OG later  
- **No** `google-site-verification` / Bing `msvalidate` meta in homepage HTML (repo src either) — see § Search Console below  
- Homepage already has `FAQPage` + `SoftwareApplication` JSON-LD; `/faq` has `FAQPage`; `/features` is thin WebPage-only

### AEO — extractable FAQ answers

| Question | Today | Gap |
|----------|--------|-----|
| Bank login? | On `/` FAQ + `/faq` (“Does Vittora require bank login?”) + JSON-LD on home | **Strong** — keep; ensure identical wording site-wide |
| Where data lives? | On `/` FAQ + security/privacy | Add explicit FAQ entry on `/faq` if not duplicated (home has it; `/faq` list from fetch emphasized bank/ads/price/devices/tax-filing) — **promote “Where is data stored?” onto `/faq` body + FAQPage schema** |
| Devices? | Present but polluted with Vision Pro roadmap | Fix answer; remove Vision |
| Pro vs free? | Pricing FAQ has good Pro list + prices | Mirror a **price-free** one-paragraph extract on `/faq` for answer engines; keep prices on `/pricing` |

**Propose FAQ/JSON-LD only where missing:**  
- Ensure `/faq` FAQPage JSON-LD includes: bank login, data location, devices (no Vision), Pro vs free (features, not only price).  
- Do **not** add schema for Saved filters, Vision Pro, net worth over time, M2.4.

---

## 2) First 10 SEO/AEO pages to add

No M2.4. No saved filters. No Vision Pro app. Draft URLs for approval only.

| # | Proposed URL / title | Target query | Angle (one sentence) |
|---|----------------------|--------------|----------------------|
| 1 | `/compare/vittora-vs-ynab` — Vittora vs YNAB | ynab alternative private / no bank | Category budgeting culture vs private offline Apple ledger that never asks for a bank password. |
| 2 | `/compare/vittora-vs-mint` — Vittora vs Mint (what replaced it) | mint alternative no bank login | For people who liked Mint’s clarity but refuse aggregation — manual/private capture on Apple devices. |
| 3 | `/compare/vittora-vs-monarch` — Vittora vs Monarch Money | monarch money alternative privacy | Household net-worth dashboards vs personal offline-first ledger + optional private iCloud only. |
| 4 | `/compare/vittora-vs-copilot` — Vittora vs Copilot Money | copilot money alternative no bank | AI + bank-link insight apps vs no-tracker, no-bank-login Apple finance. |
| 5 | `/compare/vittora-vs-splitwise` — Splitwise vs Vittora splits | splitwise vs expense tracker apple | Splits-only IOUs vs full ledger + splits/debt on iPhone/iPad/Mac/Watch. |
| 6 | `/guides/finance-app-that-doesnt-connect-to-your-bank` | finance app that doesn’t connect to your bank | Category + AEO page answering the query in the first paragraph with Vittora’s model. |
| 7 | `/guides/us-tax-season-tracking-with-vittora-pro` | us tax season expense tracking app | Expand intent from existing blog into a Pro-qualified landing (link blog; don’t duplicate fluff). |
| 8 | **Expand (don’t replace)** `/blog/old-vs-new-tax-regime-in-india-what-to-track-during-the-year/` + optional hub `/guides/india-80c-80d-tracking` | india 80c 80d tracker / old vs new regime | Keep the Jul blog as the narrative; add a short hub that states tracking is **Vittora Pro**, educational only. |
| 9 | `/compare/vittora-vs-moneycoach` — Vittora vs MoneyCoach | moneycoach alternative apple | Apple-budget peer; differentiate Watch + Year in Review + IN/US tax (Pro). |
| 10 | `/compare/vittora-vs-et-money` — Vittora vs ET Money | et money alternative privacy | India wealth/aggregation apps vs private money clarity without portfolio aggregation. |

**Not adding:** more “how to budget” / spreadsheet-killer posts (already have one).

---

## 3) ASO draft vs LIVE 1.7.0 listing

**Live today (US/IN):** name Vittora · subtitle `Private money, every device` · promo leans Year in Review / Watch / Spanish · description still includes risks (net worth; What’s New 1.5.0 interactive-widget history; ASC Vision compatibility).

### Proposed (do not upload)

| Field | Proposed | Notes |
|--------|----------|--------|
| **Name** | Vittora | Keep |
| **Subtitle (30)** | `Private ledger. No bank login.` | Anti-Mint; privacy ICP |
| **Keywords US** | `budget,expense,receipt,ocr,savings,subscription,split,debt,tax,401k,ira,icloud,offline,hindi` | Omit words in name/subtitle |
| **Keywords IN** | `budget,expense,receipt,ocr,savings,subscription,split,debt,tax,80c,80d,icloud,offline,hindi` | Storefront-local tax |
| **Promo** | Privacy + devices + tax **(Pro)** | ≤170 chars; no social proof (0 ratings) |
| **Description** | Lead no bank login / offline / private iCloud; free vs Pro exact to FEATURE_STATUS; EN/Hindi/Spanish; YiR; Watch+widgets **without** “add without opening app”; strip net worth, Vision, saved filters, 1.7.1 | Full draft already in prior ASO file; re-paste only after claim kills on site |

### Re-check the hour 1.7.1 is live

1. What’s New field → paste `Docs/Store/WHATS_NEW_1.7.1.md` locale blocks  
2. Subtitle/keywords still valid (paywall clarity doesn’t change ICP keywords)  
3. Promo: optional one line on clearer Pro plans — **no** unshipped features  
4. Description: only if free/Pro / Family Sharing wording must match new paywall  
5. Site `softwareVersion` + homepage pill → 1.7.1 in same release train  
6. Ratings still likely low — still no fake social proof  

**Hold:** full keyword rewrite experiment until listing refresh is live (per prior plan).

---

## 4) What’s New 1.7.1 (EN, es-MX, hi)

Already drafted at:

`/Volumes/Data/Projects/Vittora/Vittora/Docs/Store/WHATS_NEW_1.7.1.md`

Scope locked: rebuilt Pro paywall (Monthly / Annual / Lifetime), trial label, Family Sharing on Annual + Lifetime, store hidden when Apple payments off, entitlement copy. No prices. No CI / iOS 27 / StoreKit paths / M2.4 / saved filters / investment planning.

**English (ASC paste):**

```
PRO PAYWALL, REBUILT
• The Pro upgrade screen is clearer: Monthly, Annual, and Lifetime as a third plan
• The trial label shows correctly on Annual when you're eligible
• Family Sharing is stated on Annual and Lifetime

WHEN APPLE PAYMENTS ARE OFF
• If Apple payments are turned off on the device — Screen Time or a managed device — the store stays hidden so you aren't sent into a purchase you can't complete

CLEARER ENTITLEMENTS
• Copy for family members and Lifetime access matches what you actually have

Still no accounts, no ads, no tracking — your data stays on your devices.
```

(es-MX and hi blocks in the same file.)

---

## Search Console + Bing on `enerjik.ops@gmail.com`

**Current:** no Google/Bing verification meta on the live homepage; no verification strings found in `VittoraWebsite/src`.

**Recommended (no DNS change without Rahul):**

1. Sign into [Google Search Console](https://search.google.com/search-console) as **`enerjik.ops@gmail.com`**.  
2. Add property `https://www.vittora.app` (URL-prefix).  
3. Prefer **HTML tag** verification: Meta will give a `<meta name="google-site-verification" content="…">` — Grove/Priya add to Astro layout in a PR you approve (not DNS).  
4. Alternate: HTML file upload to `public/` on Vercel — also no DNS.  
5. Submit `https://www.vittora.app/sitemap-index.xml`.  
6. Bing Webmaster: sign in with same Google account or Microsoft account tied to ops; use **Meta tag** or **import GSC** after Google verifies — again avoid DNS unless you explicitly want CNAME verification later.

**Do not** touch DNS TXT/CNAME until you say go.

---

## Approval checklist (stop here)

- [ ] Kill Saved filters + Vision Pro + net worth claims on site (Priya/Rahul)  
- [ ] Pro-qualify `/tax-planning` (+ features tax blurbs)  
- [ ] FAQ/JSON-LD tighten (data location + Pro vs free; no Vision)  
- [ ] First-10 page list (table §2) — which to build first  
- [ ] ASO fields — approve but **do not upload** until claim hygiene + prefer post-1.7.1 hour  
- [ ] What’s New 1.7.1 — ready for ASC when build ships  
- [ ] Search Console HTML-tag path for enerjik.ops  

No site or store edits until Rahul approves.
