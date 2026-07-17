# Launch-Day Copy — Product Hunt + Social

Paste-ready copy for the coordinated launch morning (plan §9). Fill in the
two placeholders before posting: `[APP STORE URL]` and `[PH URL]` (the
Product Hunt page link, once the listing is scheduled). Character limits
are stated per field and all copy fits them.

Launch-morning order: schedule the Product Hunt listing for 12:01 AM PT →
release both apps manually → post the X thread → LinkedIn → Reddit →
update `appLinks.ts` on the website.

---

## Product Hunt

**Name:** Vittora

**Tagline** (60 chars max — this is 51):

```
Private personal finance for iPhone, iPad, and Mac
```

**Description** (260 chars max — this is 257):

```
Track spending, budgets, savings goals, shared expenses, and tax estimates — without linking a bank account. It all lives on your device and syncs through your own iCloud. No accounts, no ads, no trackers, no data selling. Free, with every feature included.
```

**Topics:** Fintech · Personal Finance · Privacy · Mac · iPhone

**Gallery:** use `Docs/Store/screenshots/marketing/` — lead with
`iphone-69/01-dashboard.png`, then mac/01, ipad-13/01, iphone-69/03
(budgets), iphone-69/05 (reports). Reuse the ASC preview video if made.

**Maker's first comment:**

```
Hi Product Hunt! 👋

I built Vittora because every finance app I tried made the same demand: hand over your bank login to a third-party aggregator, or upload your entire financial life to someone's cloud. For the most sensitive dataset you own, that always felt backwards.

Vittora takes the opposite bet:

🔒 No bank linking — you enter what you spend (it takes seconds, and the data is actually clean)
📱 Offline-first — a local database on your iPhone, iPad, or Mac; the app is fully functional in airplane mode
☁️ Sync through YOUR iCloud — your devices stay in sync via your personal iCloud private database. We run zero servers and technically cannot see your data. The privacy manifest declares zero collected data types.
🚫 No accounts, no ads, no trackers, no analytics SDKs

What's inside: expense/income tracking with quick capture, category budgets with overspend warnings, savings goals, group expense splitting, a lent/borrowed debt ledger, recurring transactions, reports (category breakdown, trends, cash flow, net worth), CSV import/export, Face ID/Touch ID app lock — and a lightweight tax estimator: US federal (with 401(k)/IRA headroom) or India's old-vs-new regime comparison.

It's free. Every feature, every device — no trial timers, no locked features. If we ever add optional paid conveniences, recording and exporting your own data stay free. That's a commitment, not a launch promo.

Native SwiftUI on all three platforms — real sidebar + split views on Mac and iPad, not a stretched phone app.

I'd genuinely love feedback — especially from folks who've bounced off finance apps before. What would make you track for more than two weeks?
```

---

## X / Twitter — launch thread

**Tweet 1 (the hook):**

```
Your finance app shouldn't need your bank password.

Today we're launching Vittora — a personal finance app for iPhone, iPad & Mac where your data never touches our servers. Because we don't have any.

Free. Every feature. [APP STORE URL]
```

**Tweet 2:**

```
The standard finance-app deal: hand your bank login to an aggregator, get your transaction history uploaded to a vendor cloud, and hope their business model never needs to sell it.

Vittora's deal: your data lives on your device and syncs through your own iCloud. We never see it.
```

**Tweet 3:**

```
What you get:

💸 10-second expense capture
📊 Category budgets that warn before you overspend
🎯 Savings goals with live progress
👥 Split group expenses + a lent/borrowed ledger
🧾 Tax estimates (US federal / India old-vs-new regime)
📈 Reports: trends, cash flow, net worth
```

**Tweet 4:**

```
Fully native on all three screens — not a stretched phone app.

iPhone for capture, iPad for planning, Mac for deep review. One private iCloud sync between them. Works completely offline.
```

**Tweet 5 (the close):**

```
Free at launch, every feature included. No ads, no trackers, no accounts, no trial timers.

App Store: [APP STORE URL]
Product Hunt (an upvote means a lot today 🙏): [PH URL]
```

---

## LinkedIn (founder-led, India-leaning per plan §9)

```
After months of building, Vittora is live on the App Store today.

It's a personal finance app for iPhone, iPad, and Mac with one unusual design decision: we never see your data. There's no sign-up, no server, no bank-account linking. Your transactions live on your device and sync through your own iCloud — not our cloud, because we don't have one.

Why build it this way? Because your spending history is one of the most revealing datasets about you that exists — where you live, what you earn, who you owe. Most apps ask you to trade it for convenience. We think you shouldn't have to.

What it does:
• Track expenses, income, and transfers in seconds — UPI, card, or cash
• Category budgets with overspend warnings
• Savings goals, group expense splitting, and a lent/borrowed ledger
• Tax estimates — old vs new regime comparison for India, federal estimate with 401(k)/IRA headroom for the US
• Reports: category breakdown, spending trends, cash flow, net worth
• CSV import/export — your data is never locked in

It's free, with every feature included, on iPhone, iPad, and Mac.

If you've ever abandoned an expense tracker after two weeks, I'd love for you to try this one and tell me why you stopped last time: [APP STORE URL]
```

---

## Reddit

⚠️ Read each subreddit's self-promotion rules before posting; several
require participation history or maker-flair. Post as a maker being
transparent, engage in comments all day, and don't cross-post the same
text verbatim.

**r/apple (or r/macapps — title):**

```
I built a native SwiftUI personal finance app for iPhone, iPad & Mac that syncs via your own iCloud — no accounts, no servers, free
```

**Body:**

```
After bouncing off finance apps that all wanted bank credentials or a vendor cloud, I built Vittora: an offline-first tracker where the database lives on your device and sync runs through your personal iCloud private database (NSPersistentCloudKitContainer). We operate zero servers; the App Store privacy label is "Data Not Collected."

Fully native SwiftUI on all three platforms — proper sidebar + split view on Mac/iPad rather than a scaled-up iPhone app. Budgets, savings goals, expense splitting, a debt ledger, recurring transactions, reports, CSV import/export, Face ID/Touch ID lock, and a lightweight tax estimator (US + India).

Free with every feature included — no trial, no locked features, no ads.

Happy to answer anything about the CloudKit/SwiftData setup or the no-backend architecture. [APP STORE URL]
```

**r/personalfinance-adjacent subs (r/budgetfood-style casual subs, r/IndiaInvestments daily thread — shorter, humbler):**

```
I got tired of expense trackers wanting my bank login, so I built one that works fully offline — data stays on your phone, syncs through your own iCloud, free with all features. It does budgets, splitting, a lent/borrowed ledger, and an old-vs-new regime tax comparison. Would love honest feedback from people who actually track: [APP STORE URL]
```

---

## Website flip (same morning)

1. `src/config/appLinks.ts` → set `appStore` to the real URL, redeploy —
   the "Coming soon" badge becomes a Download link automatically.
2. Sanity-check /download and the header CTA after deploy.
```
