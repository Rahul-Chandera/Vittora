# App Store Submission Checklist (1.0)

**Companion to `Docs/Audit/M2_T3_STORE_METADATA_PACKS.md`** (which holds name, subtitle,
keywords, promotional text, descriptions, What's New, and screenshot scripts for
en-US + en-GB). This document holds everything *else* App Store Connect asks for,
with the decided value for each field. Work top to bottom on submission day.

---

## 1 · Decisions (enter as-is)

| ASC field | Value | Notes |
|---|---|---|
| **Primary category** | **Finance** | Only honest fit. |
| **Secondary category** | *(none)* | A second category dilutes ranking; nothing else fits. |
| **Price** | Free | F0 Option A (DEC-008): no IAP, no subscription at 1.0. |
| **Availability** | United States + India (+ worldwide optional) | M1 Wave-1 = US ∥ India. Simplest compliant choice: release worldwide, market US+India only. |
| **Copyright** | `© 2026 EnerjikTech` | Adjust to the exact legal entity name on the Apple Developer account. |
| **Age rating** | 4+ | Questionnaire: answer **None/No** to every content category (no UGC, no gambling — the app has no user-generated *shared* content, no web access, no mature themes). |
| **EU DSA trader status** | Declare per your situation | Required for EU availability; if skipping EU at 1.0, mark unavailable there instead. |

## 2 · App Privacy (nutrition labels)

Answer the ASC questionnaire as **"Data Not Collected"** — the app has zero
telemetry, zero third-party SDKs, no accounts, and no developer-accessible
storage (verified in M2-D1(a); `PrivacyInfo.xcprivacy` is in-repo).

> Rationale if Review asks: all financial data is stored on-device and in the
> user's **private** iCloud database (CloudKit private DB). The developer cannot
> access it, so under Apple's definitions it is not "collected".

## 3 · URLs (host `Docs/Store/site/` first)

The `site/` folder next to this file is a self-contained static site
(index / support / privacy / terms, no build step). Host it (GitHub Pages of a
public repo is fine), then fill in:

| ASC field | URL (after hosting) |
|---|---|
| **Privacy Policy URL** | `https://<your-host>/privacy.html` |
| **Support URL** | `https://<your-host>/support.html` |
| **Marketing URL** (optional) | `https://<your-host>/` |

- [ ] ⚠️ Confirm the contact address on the site (`support@vittora.app`) is a
  real mailbox you monitor — replace across the three HTML files if not.

**GitHub Pages in 3 steps:** create a public repo (e.g. `vittora-site`) → copy the
four files from `Docs/Store/site/` to its root → Settings → Pages → deploy from
`main`. URL becomes `https://<user>.github.io/vittora-site/…`.

## 4 · App Review Information

- **Sign-in required:** No (no accounts exist).
- **Contact:** your name / phone / email.
- **Notes for Review (paste verbatim):**

> Vittora is a fully offline-first personal finance app. No account or sign-in
> exists — all features are usable immediately after the onboarding flow
> (pick currency → enter any name → create one account with any balance).
> There is no server component: data is stored on-device and optionally in the
> user's private iCloud (CloudKit). The app contains no analytics or tracking,
> which matches our "Data Not Collected" privacy answers. Tax figures are
> clearly labeled as planning estimates in-app (see Tax tab disclaimer).
> Camera/Photos/Contacts permissions are optional and only requested when the
> corresponding feature (receipt scan, attach image, payee import) is used.

## 5 · Screenshots (the remaining big task)

Scripts (content + captions) are in `M2_T3_STORE_METADATA_PACKS.md`. Required sets:

| Device class | Size (portrait) | Set |
|---|---|---|
| iPhone 6.9" (e.g. 17 Pro Max sim) | 1320 × 2868 | 6 per locale, per the scripts |
| iPad 13" (e.g. iPad Pro 13" sim) | 2064 × 2752 | 6 per locale |
| Mac (only if shipping the Mac build at 1.0) | 2880 × 1800 (16:10) | reuse the same 6 scenes |

Capture: run the seeded build on each simulator, `xcrun simctl io <sim> screenshot`.
Overlay captions per script (or submit clean screenshots — captions optional).

- [ ] Decide: is the **Mac build in scope for 1.0**? (Pending your Mac test pass.)
  If not, uncheck macOS in ASC and skip the Mac set.

## 6 · Build & signing

- [ ] Xcode → Signing: Distribution certificate + App Store profile for
  `com.enerjiktech.vittora` (iCloud/CloudKit, App Groups, background modes
  entitlements must be on the App ID).
- [ ] Bump the marketing version if desired (currently `v0.1.0 (1)` — consider `1.0.0`).
- [ ] **CloudKit: deploy the schema to Production** in CloudKit Console before
  release — dev-environment schemas don't serve TestFlight/App Store builds.
- [ ] Archive (Any iOS Device) → upload via Organizer. Export compliance is
  pre-answered (`ITSAppUsesNonExemptEncryption = false` in Info.plist).
- [ ] TestFlight-install the uploaded build on a real device before submitting.

## 7 · Submission-day order

1. Host the site (§3) → paste URLs into ASC.
2. Create the app record: bundle id, name (en-US), primary language en-US.
3. Enter §1 decisions (category, price, availability, age rating, copyright).
4. App Privacy → "Data Not Collected" (§2).
5. Add en-GB localization; paste both metadata packs from `M2_T3_STORE_METADATA_PACKS.md`.
   - [ ] Verify the India storefront picks up en-GB (M2-T3 open item).
6. Upload screenshots (§5).
7. Upload build (§6), attach to the version, fill Review info (§4).
8. Release option: **Manually release this version** (recommended for 1.0).
9. Submit.
