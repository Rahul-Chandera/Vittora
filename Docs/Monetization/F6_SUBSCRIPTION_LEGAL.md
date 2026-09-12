# F6 — Subscription legal groundwork (1.7.0)

**Status: Repository copy applied 2026-09-12 (sections 2, 3, and 5).** Nothing has
been published to the live website, submitted to App Store Connect, or otherwise
released. App Store Connect commercial configuration is still outstanding. Prices
below follow DEC-013 (annual $39.99 with a 7-day free trial; the $29.99 first-year
intro from DEC-011 is dropped).

**Build-flag conditionality (open):** The repository copy now describes the paid
app (Vittora Pro / IAP), but `MonetizationConfiguration.isStoreKitEnabled` is
still `false` on release/1.7.0 — a binary built today has no paywall and no
purchase flow. Whichever state the submitted build is in, the store listing,
App Review notes, and launch copy must match it. See open item 5 below.

---

## 1. Auto-renew disclosure — required on the paywall itself

App Review 3.1.2 requires all of the following in the **binary**, visible before the user
commits to a purchase. A paywall missing any one of them is a routine rejection.

Required element | Where it is satisfied
---|---
Title of the subscription | Plan cards ("Vittora Pro — Annual" / "Monthly")
Length of subscription and what it includes | Plan cards + feature list
Price, and price per unit where relevant | From `Product.displayPrice` — never a hardcoded string
Charged to Apple Account at confirmation | Disclosure block below
Auto-renews unless turned off ≥24h before period end | Disclosure block below
Charged for renewal within 24h before period end | Disclosure block below
Manage / turn off auto-renew in Account Settings | Disclosure block below
Unused free-trial portion forfeited on purchase | Disclosure block below (annual only)
Links to Terms of Use and Privacy Policy | Footer links, both required
Restore Purchases control | Paywall footer — required, and a common rejection when absent

### Proposed disclosure copy (annual, with trial)

> Your 7-day free trial starts when you subscribe, and your Apple Account is charged
> $39.99 when it ends. Vittora Pro renews yearly unless you turn off auto-renew at least
> 24 hours before the period ends. Renewals are charged within 24 hours of the period
> ending. You can manage or cancel your subscription in your Apple Account settings. If
> you subscribe before the trial ends, the unused part of the trial is forfeited.

### Proposed disclosure copy (monthly, no trial)

> Your Apple Account is charged $4.99 when you subscribe. Vittora Pro renews monthly
> unless you turn off auto-renew at least 24 hours before the period ends. Renewals are
> charged within 24 hours of the period ending. You can manage or cancel your
> subscription in your Apple Account settings.

### Proposed copy (lifetime)

> A one-time purchase. Vittora Pro Lifetime does not renew and is not a subscription.
> It is shared with your Family Sharing group.

**Implementation notes for F2 (do not build yet):**

- Every string above goes through `String(localized:)` and must be translated into `es`
  and `hi` — `Vittora/Localizable.xcstrings` carries `en`, `es`, `hi` today, and an
  untranslated paywall is worse than an untranslated settings screen.
- **The price must never be hardcoded into the localized string.** Interpolate
  `Product.displayPrice`, which is already localized and storefront-correct. Hardcoding
  "$39.99" breaks every non-US storefront and violates the house `Decimal` rule the moment
  someone tries to compute it.
- `SubscriptionStoreView` supplies some of this chrome automatically, but not all of it —
  the disclosure block still has to be provided as the view's subscription-policy content.

---

## 2. `Vittora/Resources/Legal/TermsOfService.md`

**Applied 2026-09-12.** The Pricing section and the new Subscriptions and auto-renewal
section below are now in the file (and mirrored into `Docs/Store/site/terms.html`).
`Last updated:` set to September 12, 2026.

```markdown
## Pricing

Vittora is free to use. Some features are part of Vittora Pro, a paid upgrade available as
an auto-renewing subscription or a one-time lifetime purchase. iCloud sync, unlimited
transactions, expense splitting, and exporting your own records as CSV remain free and are not part of Vittora Pro.

## Subscriptions and auto-renewal

Vittora Pro subscriptions are sold through the App Store and charged to your Apple Account.

- Subscriptions renew automatically at the end of each period unless auto-renew is turned
  off at least 24 hours before the period ends.
- Your Apple Account is charged for renewal within 24 hours before the current period ends.
- You can view, manage, and cancel subscriptions in your Apple Account settings. Deleting
  the app does not cancel a subscription.
- The annual plan may include a free trial. If you subscribe before a trial ends, the
  unused portion of the trial is forfeited.
- Vittora Pro Lifetime is a one-time purchase and does not renew.
- Annual and lifetime purchases can be shared through Apple's Family Sharing.
- Refunds are handled by Apple under the Apple Media Services Terms and Conditions. We
  cannot issue refunds for App Store purchases directly.
- Prices vary by storefront and may change; you will always see the current price before
  you are charged.
```

---

## 3. `Vittora/Resources/Legal/PrivacyPolicy.md`

**Applied 2026-09-12.** Appended under "What data Vittora stores":

```markdown
- Whether you have an active Vittora Pro purchase, stored on your device only
```

and under "What Vittora does not do":

```markdown
- Send purchase or subscription information to any server we operate
```

Mirrored into `Docs/Store/site/privacy.html`. `Last updated:` set to September 12, 2026.

That claim is currently accurate: the entitlement lives in `EntitlementCache`
(`Vittora/Core/Monetization/Entitlement.swift`) inside the isolated
`AppUserDefaults.conversion` suite, holds only a product identifier and dates, and never
leaves the device. **This claim must be re-verified at F2/F4** — it stops being true the
moment anyone adds server-side receipt validation or an analytics call on purchase.

---

## 4. App Store privacy nutrition label — what actually changes

**Nothing.** This is the conclusion, and it is worth stating plainly because the intuitive
answer is wrong.

Apple's App Privacy questionnaire asks what data **your app** collects — meaning data
transmitted off the device by your code or an SDK you embed. Purchases made through
StoreKit are processed by Apple, not by Vittora, and Apple's own handling of that
transaction is out of scope for the developer's declaration.

Questionnaire item | Today | After IAP | Why
---|---|---|---
Purchases → Purchase History | Not collected | **Not collected** | The entitlement never leaves the device; there is no server, no receipt upload, no analytics
Identifiers → User ID / Device ID | Not collected | **Not collected** | StoreKit 2 needs no account and Vittora stores no Apple Account identifier
Usage Data → Product Interaction | Not collected | **Not collected** | F5 milestones are local-only by deliberate design and are not transmitted
Contact Info / Financial Info | Not collected | **Not collected** | Unchanged
Tracking (`NSPrivacyTracking`) | `false` | **`false`** | No cross-app tracking, no ad network, no attribution SDK

`Vittora/PrivacyInfo.xcprivacy` also needs **no change**: StoreKit is not a required-reason
API, and the only declared category (`NSPrivacyAccessedAPICategoryUserDefaults`, reason
`CA92.1`) already covers the entitlement cache, which uses the app's own defaults suite.

**The "no accounts, no ads, no tracking" positioning survives IAP intact.** What changes is
only the App Store Connect *commercial* configuration — a different section of the same
console:

- In-App Purchases: three products created, priced, localized, screenshot-attached, and
  submitted for review with the build
- Subscription group "Vittora Pro" with both plans, group display name, and ranking
- The annual introductory offer
- Family Sharing toggled on for annual and lifetime, off for monthly
- App-level **Terms of Use (EULA)** and **Privacy Policy** URLs — both become mandatory for
  an app with auto-renewing subscriptions
- The app's price tier stays Free; the badge becomes "Offers In-App Purchases"

**Do not conflate the two.** If anyone answers "yes, we collect Purchases" on the privacy
questionnaire out of caution, the listing gains a Data Collected card that contradicts the
entire marketing position, for no regulatory benefit.

---

## 5. Marketing and store copy that becomes false

Inventory of what was found and what was changed on 2026-09-12. The original draft's
grep missed several lines; those are listed too.

File | Line | Problem | Action (2026-09-12)
---|---|---|---
`Vittora/Resources/Legal/TermsOfService.md` | 32 | "offered without in-app purchases or subscriptions" | **Updated** — Pricing + Subscriptions sections
`Docs/Store/site/terms.html` | 43 | same sentence, published on the website | **Updated** (repo only; not deployed)
`Docs/Store/APP_REVIEW_NOTES.md` | 28 | "app is 100% free at launch, no IAP" | **Updated**
`Docs/Store/APP_REVIEW_NOTES.md` | 151 | "the app is free, no in-app purchases" | **Updated**
`Docs/Store/APP_REVIEW_NOTES.md` | 233 | "No payment processor (app is free, no IAP yet)" | **Updated**
`Docs/Store/LAUNCH_COPY.md` | 27 | "Free, with every feature included" | **Updated** (≤260 chars)
`Docs/Store/LAUNCH_COPY.md` | 52 | "It's free. Every feature… no locked features" | **Updated** — commitment kept for recording/export/sync/splitting
`Docs/Store/LAUNCH_COPY.md` | 105 | "Free at launch, every feature included" | **Updated**
`Docs/Store/LAUNCH_COPY.md` | 130 | "It's free, with every feature included" | **Updated**
`Docs/Store/LAUNCH_COPY.md` | 157 | "Free with every feature included" | **Updated**
`Docs/Store/APP_STORE_SUBMISSION_CHECKLIST.md` | 16 | Price = Free per DEC-008 | **Updated** — Free with IAP; privacy note + IAP config section added
`Docs/Store/metadata-en-IN.md` | header | "Free, no IAP (DEC-008). Pro… must not appear" | **Header updated** + TODO for description
`Docs/Store/metadata-en-US.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-hi.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-mac-es-US.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-mac-en-IN.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-mac-en-US.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-mac-hi.md` | header | same | **Header updated** + TODO
`Docs/Store/metadata-*.md` description bodies | en / es / hi "every feature" lines | **Left alone** pending owner sign-off before 1.7.0 submission

Safe as written, because they are about ads and tracking rather than price — do **not**
rewrite these, the claims stay true:

- `Docs/Store/metadata-*.md` "No ads, no trackers, no analytics sold to anyone"
- `Docs/Store/WHATS_NEW_*.md` "Still no accounts, no ads, no tracking"

`Vittora/Resources/AppStoreMetadata/description.txt` makes no pricing claim and needs no
change for correctness — though it will want a Vittora Pro paragraph for conversion.

Nothing in the app's own UI strings claims the app is free; the grep found no in-binary
pricing claim to retract.

---

## 6. Open questions for the owner

1. **SETTLED by DEC-013.** The annual plan cannot have both a 7-day free trial and a
   $29.99 first-year price. App Store subscriptions allow exactly one introductory offer
   per user per subscription group, and free trial / pay-up-front are mutually exclusive
   types of that one offer. DEC-011 specified both. Owner ruling (DEC-013): **trial only,
   hero price $39.99**; the $29.99 intro price is dropped. Offer codes remain available for
   marketing and win-back per §8.
2. Terms and Privacy Policy currently ship inside the app. Auto-renewing subscriptions
   require **publicly reachable URLs** in App Store Connect. `Docs/Store/site/` exists —
   confirm those pages are live and that their URLs are the ones to register.
3. Refund and support contact: the Privacy Policy's contact section says "the support
   channel associated with your distribution", which is too vague once money changes hands.
4. **Localized App Store description copy** in the seven `metadata-*.md` files still claims
   every feature is free, in English, Spanish, and Hindi. Headers were updated with a TODO;
   body copy needs owner sign-off before the 1.7.0 submission.
5. **`MonetizationConfiguration.isStoreKitEnabled` vs. submitted documents.** Repository
   copy (Terms, Privacy, store docs, review notes, launch copy) now describes the paid
   app. The flag is still `false`, so a 1.7.0 binary built today has no paywall and no
   purchase flow. Before submission, either flip the flag (owner decision) and keep the
   paid-app documents, or leave the flag off and strip/revert the IAP claims in every
   document handed to Apple so they match the free-only binary. Store and review
   documents must match the submitted build either way.
