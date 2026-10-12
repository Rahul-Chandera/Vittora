# Custom product pages — 1.8.1

Four pages, each aimed at one audience: its own lead screenshots, promotional
text, keywords and deep link. App Store Connect › Growth & Marketing › Custom
Product Pages. iPhone and iPad only (the Mac listing has no custom pages).

**Screenshots:** `Marketing/AppStore/cpp/<page>/<locale>/{iphone-69,iphone-65,ipad-13}/`,
upload in file order. Regenerate with `Scripts/store/make_cpp.py` after
`make_marketing.py`.

**Setup, per page:**
1. Create Custom Product Page › Reference Name (below) › **Copy Existing Product
   Page**, so every localization starts filled in.
2. For each localization listed: replace the screenshots, paste the promotional
   text, tick the keywords listed, set the deep link.
3. Remove localizations a page does not list from that page, or leave them on
   the copied default (they then show the default page's content).
4. Add for Review › Submit. No build needed, but **deep links need 1.8.1**
   (`vittora://tax` is new in it); submit the tax pages after 1.8.1 is live.
5. Copy each page's URL (`…?ppid=…`) into the table at the bottom.

**Rules these follow:**
- Keywords are **ticked, not typed**: a page can only claim keywords from the
  version's own keyword field, and each keyword belongs to one page at a time.
  A ticked keyword shows that page in search instead of the default page. The
  1.8.1 keyword fields (Docs/Store/metadata-*.md) were revised so every page has
  one to claim; the boxes appear once 1.8.1's metadata is saved.
- No competitor names (Mint, YNAB) anywhere: guideline 2.3.7.
- AI is named nowhere here; suggestions and estimates are described plainly.
- Tax copy says "estimate" and names no figures beyond what the screenshots show.

---

## 1. Tax – India

Reference name: `Tax – India` · Deep link: `vittora://tax`

Audience: salaried people in India around filing time, searching for an income
tax calculator.

| Locale | Screenshots |
|---|---|
| en-IN | 1 slide: the India estimator in rupees (the en-IN store gallery is in dollars, so nothing else is reused) |
| hi | Tax first, then dashboard, budgets, net worth, reports, all in rupees |

**en-IN**
- Promotional text:
  ```
  See your income tax under the old and new regime for FY 2026-27, with 80D, NPS and HRA. An educational estimate, calculated on your iPhone. No bank login.
  ```
- Keywords — tick: `tax`, `regime`, `80C`

**hi**
- Promotional text:
  ```
  FY 2026-27 के लिए पुरानी और नई टैक्स व्यवस्था में अपना इनकम टैक्स देखें, 80D, NPS और HRA के साथ। आपके iPhone पर बना अनुमान। कोई बैंक लॉगिन नहीं।
  ```
- Keywords — tick: `टैक्स`, `80c`, `आयकर`

---

## 2. Tax – UK, Canada, Australia

Reference name: `Tax – UK, Canada, Australia` · Deep link: `vittora://tax`

Audience: the wave 2 countries, all on the en-US localization (UK, Canadian and
Australian storefronts fall back to it).

| Locale | Screenshots |
|---|---|
| en-US | UK, Canada, Australia estimators, each in its own currency with its own headline |

**en-US**
- Promotional text:
  ```
  Estimate your income tax in the UK, Canada or Australia: National Insurance, provincial tax, the Medicare levy. Educational, calculated on your device.
  ```
- Keywords — tick: `tax calculator`

---

## 3. Household budgets

Reference name: `Household budgets` · Deep link: `vittora://budget`

Audience: couples, families and flatmates who want one shared budget.

| Locale | Screenshots |
|---|---|
| en-US, en-IN, hi, es | Household first, then budgets, dashboard, transactions, net worth |

**en-US**
- Promotional text:
  ```
  Share budgets with the people you live with through iCloud. See who spent what, and choose who can edit. Free, with no accounts and no bank login.
  ```
- Keywords — tick: `shared budget`

**en-IN** — promotional text as en-US.
- Keywords — tick: `shared budget`

**es**
- Promotional text:
  ```
  Comparte presupuestos con las personas con las que vives a través de iCloud. Mira quién gastó qué y elige quién puede editar. Gratis y sin conectar tu banco.
  ```
- Keywords — tick: `presupuesto compartido`

**hi**
- Promotional text:
  ```
  जिनके साथ आप रहते हैं, उनसे iCloud के ज़रिए बजट साझा करें। देखें किसने क्या खर्च किया और तय करें कौन बदलाव कर सकता है। मुफ़्त, बिना बैंक लॉगिन।
  ```
- Keywords — tick: `साझा बजट`

---

## 4. Private, no bank login

Reference name: `Private – no bank login` · Deep link: `vittora://add?type=expense`

Audience: people who will not link a bank account to a finance app.

| Locale | Screenshots |
|---|---|
| en-US, en-IN, hi, es | A "No bank login" headline on the dashboard, then transactions, budgets, net worth, Year in Review |

**en-US / en-IN**
- Promotional text:
  ```
  Track your money without linking a bank. Everything stays on your devices and in your own iCloud. No account to create, no ads, no tracking.
  ```
- Keywords — tick: `no bank login`

**es**
- Promotional text:
  ```
  Controla tu dinero sin conectar tu banco. Todo se queda en tus dispositivos y en tu propio iCloud. Sin cuentas que crear, sin anuncios y sin rastreo.
  ```
- Keywords — tick: `sin banco`

**hi**
- Promotional text:
  ```
  बैंक लिंक किए बिना अपने पैसे का हिसाब रखें। सब कुछ आपके डिवाइस और आपके अपने iCloud में रहता है। कोई अकाउंट नहीं, कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं।
  ```
- Keywords — tick: `बिना बैंक`

---

## Where to use each URL

| Page | Use it on | URL |
|---|---|---|
| Tax – India | vittora.app/tax-planning (India card), Indian posts around filing season | _paste after approval_ |
| Tax – UK, Canada, Australia | vittora.app/tax-planning (UK/CA/AU cards) | _paste after approval_ |
| Household budgets | vittora.app/features (Share section) | _paste after approval_ |
| Private – no bank login | vittora.app/security, "no bank login" guides | _paste after approval_ |

Watch App Analytics › Acquisition per page for 2–4 weeks before adding more.
