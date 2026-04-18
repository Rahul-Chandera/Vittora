# Vittora — Production Readiness Code Review

**Reviewer role:** Apple platforms architect (iOS / macOS / iPadOS)
**Review date:** 2026-04-18
**Scope:** `/Volumes/Data/Projects/Vittora/Vittora/Vittora` (Swift 6 / SwiftUI / SwiftData / CloudKit)
**Targets:** iOS 18+, iPadOS 18+, macOS 15+
**Bundle ID:** `com.enerjiktech.vittora`
**Codebase size:** 345 source files, 41 test files

---

## How to use this document (for the implementing agent)

1. Work through the **Critical → High → Medium → Low** sections in order. Within a section, the order is the order to fix in.
2. Every finding has: a stable **ID** (e.g., `SEC-01`), the exact **file path + line(s)**, the **current code**, the **expected behaviour**, and a **concrete fix**.
3. After each fix:
   - Build for **iOS Simulator** AND **macOS** (commands at the end of `CLAUDE.md`).
   - Run `xcodebuild test`.
   - Tick the checkbox at the start of the finding.
4. Do **not** introduce third-party dependencies (Apple frameworks only — see `CLAUDE.md` Rule 10).
5. Do **not** break Swift 6 strict concurrency.
6. All user-facing strings must use `String(localized:)` (Rule 9).
7. Every commit must follow Conventional Commits with `Co-Authored-By` trailer (`CLAUDE.md` "Commit Convention" section).

> **Verification commands**
> ```bash
> # iOS
> xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build \
>   -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build test
> # macOS
> xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build \
>   -destination 'generic/platform=macOS' build
> ```

---

## Executive summary

| Area | Critical | High | Medium | Low | Subtotal |
|---|---:|---:|---:|---:|---:|
| Security | 5 | 7 | 4 | 2 | **18** |
| Tax accuracy | 5 | 5 | 3 | 3 | **16** |
| Reliability / crash safety | 3 | 4 | 4 | 2 | **13** |
| Architecture & code quality | 0 | 28 | 18 | 1 | **47** |
| UX / HIG / accessibility | 4 | 9 | 8 | 9 | **30** |
| Performance & memory | 3 | 8 | 3 | 1 | **15** |
| Test coverage | — | (large gap) | — | — | **see §7** |
| **Total** | **20** | **61** | **40** | **18** | **139+** |

The app is **not production-ready** in its current state. Seven distinct categories of blocking issues must be addressed:

1. **Tax engine is wrong for both active tax years.** US uses TY 2024 brackets/deductions and misses the **OBBBA** (signed 4 Jul 2025) which changed TY 2025 standard deductions ($15,750 / $31,500 / $23,625) and introduced the age-65+ $6,000 deduction; TY 2026 (Rev. Proc. 2025-32, $16,100 / $32,200 / $24,150) is also absent. The 5th filing status (`qualifyingSurvivingSpouse`), FICA, NIIT, and capital-gains rates are missing. India uses pre-Budget-2025 slabs, the old ₹7L / ₹25k §87A cap (correct: ₹12L / ₹60k with marginal relief), the wrong new-regime standard deduction, and applies neither surcharge nor the 4% Health & Education Cess. Real users in April 2026 will be over- or under-taxed. (§2, §2A)
2. **At-rest encryption is inadequate.** Receipt/document blobs are stored unencrypted; the AES key is in plain Keychain (no Secure Enclave, no biometric ACL). (§1)
3. **App lock has no passcode fallback** and no screen-mask / screenshot redaction. (§1)
4. **Critical crash paths** (`memberIDs.last!`, `accounts[0]`, division-by-zero in budget projections, empty `catch {}` in tax-profile save). (§3)
5. **Performance**: dashboards/reports `fetchAll(filter: nil)` the entire transaction history; SwiftData models lack `@Index`/`@Unique`; formatters allocated in view bodies. (§6)
6. **No SwiftData `SchemaMigrationPlan`** — first schema change in production crashes every existing user. (§3)
7. **Test coverage**: 0% of repositories, 18% of mappers, 15% of view models. (§7)

---

# 1. Security (CRITICAL for a finance app)

> Files mostly under `Vittora/Core/Security/`, `Vittora/Core/Sync/`, `Vittora/Core/Data/Persistence/`, plus the `Info.plist` and `Vittora.entitlements`.

### CRITICAL

- [ ] **SEC-01 — Keychain items not biometric-bound.**
  **File:** [Vittora/Core/Security/KeychainService.swift:21](Vittora/Core/Security/KeychainService.swift)
  Items are written with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` only. There is no `SecAccessControl` with `.biometryCurrentSet`, so a stolen-but-unlocked device exposes the AES key without re-authenticating.
  **Fix:** create the item with `SecAccessControlCreateWithFlags(... .biometryCurrentSet, ...)` for sensitive entries (the AES master key in particular). Keep the simpler accessibility for non-sensitive items.

- [ ] **SEC-02 — Document blobs stored unencrypted.**
  **File:** [Vittora/Core/Data/Models/SDDocument.swift:9-10](Vittora/Core/Data/Models/SDDocument.swift), [Vittora/Core/Data/Repositories/SwiftDataDocumentRepository.swift](Vittora/Core/Data/Repositories/SwiftDataDocumentRepository.swift)
  `fileData: Data?` and `thumbnailData: Data?` are persisted plaintext. Receipts contain card last-4, names, merchant amounts. The `encryptedData` field exists but isn't used.
  **Fix:** route every write through `EncryptionService.encrypt(_:)` and store only `encryptedData`. Drop `fileData` from the schema (add a migration that re-encrypts existing rows). Decrypt on read.

- [ ] **SEC-03 — AES master key has no hardware backing.**
  **File:** [Vittora/Core/Security/EncryptionService.swift:51-52](Vittora/Core/Security/EncryptionService.swift)
  `SymmetricKey(size: .bits256)` is a software key serialized into Keychain as raw bytes. On a jailbroken device the key dumps with the Keychain.
  **Fix:** generate the key via `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave` (where available) and use it to wrap a symmetric key for AES‑GCM. Fall back to Keychain + biometric ACL on devices without Secure Enclave (older iPads).

- [ ] **SEC-04 — CSV exports are unencrypted in `/tmp` with no secure delete.**
  **File:** [Vittora/Core/Data/Persistence/DataExportService.swift:268-285](Vittora/Core/Data/Persistence/DataExportService.swift)
  `Data.write(to: url)` lands in the temp dir with no `.completeFileProtection` and no cleanup; the URL is then handed to a share sheet.
  **Fix:**
  ```swift
  try data.write(to: url, options: [.atomic, .completeFileProtection])
  try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
  ```
  Add a deferred cleanup step (e.g., on share-sheet completion) that overwrites with random bytes before deletion.

- [ ] **SEC-05 — CSV formula injection.**
  **File:** [Vittora/Core/Data/Persistence/DataExportService.swift:131-134](Vittora/Core/Data/Persistence/DataExportService.swift) (and the `csvEscaped` extension)
  Notes/tags are only quote-escaped. A note like `=cmd|'/c calc'!A1` executes when the user opens the CSV in Excel/Sheets.
  **Fix:** in `csvEscaped`, prefix any value starting with `=`, `+`, `-`, `@`, tab, or CR with a single quote.

### HIGH

- [ ] **SEC-06 — App-lock has no passcode fallback.**
  **File:** [Vittora/Core/Security/BiometricService.swift:42-70](Vittora/Core/Security/BiometricService.swift)
  Uses `.deviceOwnerAuthenticationWithBiometrics` only. On lockout / no-enrollment / sensor failure, the user is locked out of their own data.
  **Fix:** catch `LAError.biometryLockout` (and `.biometryNotEnrolled`/`.biometryNotAvailable`) and retry with `.deviceOwnerAuthentication` (which permits passcode). Add a dedicated "Use passcode" button in [Vittora/Features/Security/AppLockView.swift](Vittora/Features/Security/AppLockView.swift).

- [ ] **SEC-07 — No screen-mask / redaction when backgrounded.**
  **File:** [Vittora/Features/Security/AppLockView.swift](Vittora/Features/Security/AppLockView.swift) and root view ([Vittora/VittoraApp.swift](Vittora/VittoraApp.swift))
  Balances are visible in the App Switcher snapshot.
  **Fix:** add an `@Environment(\.scenePhase)` observer at the root; when phase becomes `.inactive` or `.background`, present a full-screen blur overlay above all financial UI. Use `.privacySensitive(true)` on amount text inside `AppLockView`.

- [ ] **SEC-08 — Sensitive state in `UserDefaults`.**
  **Files:**
  - [Vittora/VittoraApp.swift:99](Vittora/VittoraApp.swift)
  - [Vittora/Core/Sync/SyncStatusService.swift:42, 139](Vittora/Core/Sync/SyncStatusService.swift)
  - [Vittora/App/AppState.swift:17](Vittora/App/AppState.swift)
  - [Vittora/Core/Data/Persistence/DefaultDataSeeder.swift:13](Vittora/Core/Data/Persistence/DefaultDataSeeder.swift)
  Onboarding status, last sync date, and currency code live in `UserDefaults.standard` (plaintext plist, included in iCloud backup).
  **Fix:** move security-relevant flags (e.g., onboarding-complete, app-lock-enabled, biometric-enabled) into Keychain via `KeychainService`. Last-sync date can stay in defaults but should be in an app-group suite, not `.standard`.

- [ ] **SEC-09 — CloudKit conflict resolution is naive last-writer-wins with no integrity check.**
  **File:** [Vittora/Core/Sync/SyncConflictHandler.swift:47-59](Vittora/Core/Sync/SyncConflictHandler.swift)
  Timestamp-only LWW silently drops one side of every edit collision; no validation that incoming records are well-formed.
  **Fix:** for amount-bearing entities (`SDTransaction`, `SDBudget`, `SDAccount`, `SDDebtEntry`, `SDGroupExpense`), reject records that fail invariants (currency mismatch, negative balance for asset accounts, non-finite Decimal). On a real divergence (different `amount` AND different `note`), surface a conflict UI rather than silently picking one.

- [ ] **SEC-10 — SwiftData store not excluded from iCloud backup and no file-protection class on the store.**
  **File:** [Vittora/Core/Data/Persistence/ModelContainerConfig.swift](Vittora/Core/Data/Persistence/ModelContainerConfig.swift)
  **Fix:** after creating the container, look up the on-disk URL, set `URLResourceValues.isExcludedFromBackup = true` (only for the local-only store; the CloudKit-mirrored store should remain backed up by CK), and apply `FileProtectionType.complete` to the SQLite + WAL/SHM siblings.

- [ ] **SEC-11 — No rate-limiting / lockout on biometric attempts at app level.**
  **File:** [Vittora/Core/Security/BiometricService.swift](Vittora/Core/Security/BiometricService.swift)
  `LAContext` lockout still applies at OS level, but the app should track repeated failures and force a cool-down + audit log entry. See SEC-06 for the related fallback.

- [ ] **SEC-12 — `String.isValidURL` accepts `file://`.**
  **File:** [Vittora/Core/Extensions/String+Validation.swift:19-23](Vittora/Core/Extensions/String+Validation.swift)
  Allow only `http`/`https` (and your own custom URL scheme if you have one). Local-file URLs in user-supplied text can be weaponized in receipt notes.

### MEDIUM

- [ ] **SEC-13 — Add `ITSAppUsesNonExemptEncryption = NO` to [Vittora/Info.plist](Vittora/Info.plist).** You ship CryptoKit AES-GCM; absent this key App Store Connect blocks every build with an export-compliance prompt. (Use `NO` because AES-GCM under CryptoKit qualifies for the standard 5D002 exemption when used for app data only.)
- [ ] **SEC-14 — Confirm `NSFaceIDUsageDescription`** is present in [Vittora/Info.plist](Vittora/Info.plist) and the copy explains *why* (e.g., "Face ID is used to unlock your private financial data on this device.").
- [ ] **SEC-15 — `BiometricService` re-allocates `LAContext` on every property read.** [Vittora/Core/Security/BiometricService.swift:16-40](Vittora/Core/Security/BiometricService.swift). Cache one context per service instance; create a fresh one per `evaluate(...)` call only.
- [ ] **SEC-16 — `print(...)` in `BackgroundTaskScheduler`.** [Vittora/Core/Infrastructure/BackgroundTaskScheduler.swift:50, 62, 65](Vittora/Core/Infrastructure/BackgroundTaskScheduler.swift) — leaks operational info to system logs even in Release. Replace with `os.Logger(subsystem: "com.vittora.app", category: "background")`.

### LOW

- [ ] **SEC-17 — Add a soft jailbreak/root indicator** as informational telemetry only. Do not block the user (Apple discourages hard blocks), but down-weight features such as auto-export when detected.
- [ ] **SEC-18 — Add an encrypted audit log** for: lock/unlock, key rotation, sync conflicts auto-resolved, exports created. Append-only, file-protection-complete, surfaced in Settings → Security.

---

# 2. Tax accuracy (real money, real users)

> Today is **2026-04-18**.
> - **US:** TY 2025 returns were due **15 Apr 2026** (3 days ago). The engine must support **TY 2025** (still being filed on extension) AND **TY 2026** (planning, withholding, estimated quarterly payments now in progress). All TY 2025/2026 numbers below are **post-OBBBA** (One Big Beautiful Bill Act, signed 4 Jul 2025) per **IRS Rev. Proc. 2025-32**.
> - **India:** **AY 2026-27 / FY 2025-26** is the active year (Budget 2025 in effect since 1 Apr 2025). Returns will be due **31 Jul 2026**.
>
> Authoritative sources used to verify these numbers (web-confirmed 2026-04-18):
> - IRS Rev. Proc. 2025-32 (TY 2026 inflation adjustments)
> - IRS TY 2025 post-OBBBA standard deduction announcement
> - Income-Tax Act §115BAC (new regime) and §87A as amended by Finance Act 2025
> - Vittora_Tax_Engine_Rules_India_US_2026.md (attached spec — independently validated and adopted as the target architecture; see §2A)

### CRITICAL

- [ ] **TAX-01 — US standard deduction is wrong for both TY 2025 and TY 2026 (OBBBA missed).**
  **File:** [Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift:100-106](Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift) (and docstring at line 3).
  Current code uses TY 2024 numbers ($14,600 / $29,200 / $21,900). The fix must populate **two** rule sets, because in April 2026 the app is used both for filing TY 2025 and planning TY 2026.

  **TY 2025 (post-OBBBA — IRS Notice / Rev. Proc. 2024-40 as superseded):**
  | Filing status | TY 2025 standard deduction |
  |---|---:|
  | Single | **$15,750** |
  | Married filing separately | **$15,750** |
  | Head of household | **$23,625** |
  | Married filing jointly | **$31,500** |
  | Qualifying surviving spouse | **$31,500** |

  **TY 2026 (IRS Rev. Proc. 2025-32):**
  | Filing status | TY 2026 standard deduction |
  |---|---:|
  | Single | **$16,100** |
  | Married filing separately | **$16,100** |
  | Head of household | **$24,150** |
  | Married filing jointly | **$32,200** |
  | Qualifying surviving spouse | **$32,200** |

  Update the docstring and unit tests accordingly. **Do not** ship a single hardcoded year — see TAX-05 / §2A for the versioned-provider pattern.

- [ ] **TAX-02 — Missing 5th US filing status: `qualifyingSurvivingSpouse`.**
  **Files:** [Vittora/Core/Domain/Entities/TaxEntity.swift](Vittora/Core/Domain/Entities/TaxEntity.swift), [Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift), Tax profile UI.
  The IRS recognises five federal filing statuses; the app exposes four. QSS uses MFJ brackets and standard deduction for the two tax years following the year of the spouse's death. Add the case to the enum, mirror MFJ tables, surface it in the picker (with a help blurb explaining the eligibility window), and add a regression test.

- [ ] **TAX-03 — US bracket table is TY 2024 and lacks TY 2026 boundaries.**
  **File:** [Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift)
  Rates remain `10/12/22/24/32/35/37` for both TY 2025 and TY 2026, but every boundary moves with inflation. Replace the hardcoded table with two rule sets keyed by tax year. Use these **TY 2026** boundaries (Rev. Proc. 2025-32) as the planning default; the **TY 2025** table comes from Rev. Proc. 2024-40 as adjusted by OBBBA:

  **TY 2026 — Single (also MFS, halve MFJ):**
  | Rate | Lower | Upper |
  |---:|---:|---:|
  | 10% | $0 | $12,400 |
  | 12% | $12,400 | $50,400 |
  | 22% | $50,400 | $105,700 |
  | 24% | $105,700 | $201,775 |
  | 32% | $201,775 | $256,225 |
  | 35% | $256,225 | $640,600 |
  | 37% | $640,600 | — |

  **TY 2026 — MFJ / QSS:**
  | Rate | Lower | Upper |
  |---:|---:|---:|
  | 10% | $0 | $24,800 |
  | 12% | $24,800 | $100,800 |
  | 22% | $100,800 | $211,400 |
  | 24% | $211,400 | $403,550 |
  | 32% | $403,550 | $512,450 |
  | 35% | $512,450 | $768,700 |
  | 37% | $768,700 | — |

  HoH and MFS tables likewise; full numbers in `Vittora_Tax_Engine_Rules_India_US_2026.md` §3.2. Add the equivalent TY 2025 set behind the same year switch and write a parameterised test for every (year, status, taxable-income) row in §6 of the spec.

- [ ] **TAX-04 — India new-regime slabs are pre-Budget-2025.**
  **File:** [Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift:70-79](Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift)
  Replace with the FY 2025-26 / AY 2026-27 §115BAC slabs:
  ```swift
  private func newRegimeSlabsFY2025_26() -> [TaxSlab] {
      [
          TaxSlab(lower:         0, upper:   400_000, ratePercent:  0, label: "₹0 – ₹4L"),
          TaxSlab(lower:   400_000, upper:   800_000, ratePercent:  5, label: "₹4L – ₹8L"),
          TaxSlab(lower:   800_000, upper: 1_200_000, ratePercent: 10, label: "₹8L – ₹12L"),
          TaxSlab(lower: 1_200_000, upper: 1_600_000, ratePercent: 15, label: "₹12L – ₹16L"),
          TaxSlab(lower: 1_600_000, upper: 2_000_000, ratePercent: 20, label: "₹16L – ₹20L"),
          TaxSlab(lower: 2_000_000, upper: 2_400_000, ratePercent: 25, label: "₹20L – ₹24L"),
          TaxSlab(lower: 2_400_000, upper: nil,       ratePercent: 30, label: "Above ₹24L"),
      ]
  }
  ```

- [ ] **TAX-05 — India §87A rebate threshold, cap, and marginal relief are missing.**
  **File:** [Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift:32-36](Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift)
  New-regime branch must use threshold **₹12,00,000** and cap **₹60,000** (Budget 2025). Old-regime branch stays at ₹5,00,000 / ₹12,500. Implement marginal relief — required by law for incomes just over ₹12L:
  ```swift
  // Apply only to slab/ordinary income, not to special-rate items (LTCG/STCG/lottery).
  let ordinaryTax = slabTax(on: ordinaryTaxableIncome)
  let rebate: Decimal = {
      if ordinaryTaxableIncome <= 1_200_000 { return min(ordinaryTax, 60_000) }
      let excess = ordinaryTaxableIncome - 1_200_000   // marginal relief
      return max(0, ordinaryTax - excess)
  }()
  ```
  Add tests at ₹12,00,000 (zero tax), ₹12,10,000 (relief active), ₹12,75,000 (relief exhausted).

### HIGH

- [ ] **TAX-06 — New-regime standard deduction is wrong / missing.**
  Salaried taxpayers under the new regime in FY 2025-26 get **₹75,000** (raised from ₹50,000 in Budget 2024). Old regime stays at **₹50,000**. Verify the deduction is subtracted from gross salary income before the slab calculation, and that it is gated on `incomeType == .salary` (not available for pure business/profession income).

- [ ] **TAX-07 — `TaxProfile.financialYear` is unused; engine has no notion of years.**
  **Files:** [Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift), [Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift), [Vittora/Core/Domain/Entities/TaxEntity.swift:78-111](Vittora/Core/Domain/Entities/TaxEntity.swift)
  The calculators ignore the year. Adopt the versioned `TaxRuleSet` pattern from §2A — rule sets keyed by ID (`IN_FY2025_26_AY2026_27`, `US_FEDERAL_TY2025`, `US_FEDERAL_TY2026`) returned by a `TaxRuleProvider`, with the calculator pulling slabs/limits from the rule set. Without this, the app silently produces wrong numbers every 1 April / 1 January.

- [ ] **TAX-08 — Surcharge tiers + 4% Health & Education Cess are not applied (India).**
  **File:** [Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift)
  After computing `incomeTax + rebateAdjusted`, apply the surcharge ladder (new regime caps at 25% for income > ₹2 cr; old regime can hit 37% > ₹5 cr but check whether the user opted into the new regime), then add the **4% cess** on `(tax + surcharge)`. Currently neither is applied — high-income users see materially wrong totals.

- [ ] **TAX-09 — Rounding mode is `.bankers`; Indian and US authorities expect half-up.**
  **File:** [Vittora/Core/Infrastructure/Tax/TaxCalculatorProtocol.swift:53-58](Vittora/Core/Infrastructure/Tax/TaxCalculatorProtocol.swift)
  Change `NSDecimalRound(..., .bankers)` to `.up` (or to `.plain` for India per CBDT rounding to the nearest ₹10). Document the choice with a comment citing the authority. Use `Decimal` end-to-end — no `Double` anywhere in the tax engine (per spec §10 rule 1).

- [ ] **TAX-10 — Senior / super-senior India rules missing (old regime).**
  Old regime basic exemption is ₹3,00,000 for age 60-79 and ₹5,00,000 for 80+. Either implement (preferred — pull DOB from `TaxProfile`) or surface a top-of-screen warning when `regime == .old && age >= 60`.

### MEDIUM

- [ ] **TAX-11 — Capital gains, qualified dividends, and other special-rate income are not separated from ordinary income.**
  Both engines need an explicit split.
  - **India:** add `equityLTCG: Decimal` (12.5% above ₹1,25,000 exempt — Finance Act 2024), `equitySTCG: Decimal` (20%), debt MF / unlisted gains taxed at slab. Compute outside the slab path, add to `total`. **§87A rebate must NOT apply to special-rate income.**
  - **US:** add `qualifiedDividends`, `longTermCapitalGains` (0% / 15% / 20% thresholded by AGI), `shortTermCapitalGains` (slab). Plus **NIIT** 3.8% on the lesser of net investment income and (MAGI − $200,000 single / $250,000 MFJ).
  Spec §3.4 / §4.4 has the exact tables.

- [ ] **TAX-12 — US calculator omits FICA, NIIT, AMT, OBBBA senior $6,000 deduction.**
  **File:** [Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift](Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift)
  Add as separate result lines (do not bundle into `federalIncomeTax`):
  - **FICA payroll:** SS 6.2% to **$176,100** (TY 2025) / **$184,500** (TY 2026 — Rev. Proc. 2025-32 wage-base); Medicare 1.45% + Additional 0.9% above $200k single / $250k MFJ.
  - **NIIT:** as in TAX-11.
  - **OBBBA senior deduction:** taxpayers age 65+ get an extra **$6,000** deduction (TY 2025-2028, phases out at higher incomes — verify the AGI threshold against the final OBBBA text before shipping).
  - **AMT:** mark "out of scope" in the engine and surface in the disclaimer (TAX-15).

- [ ] **TAX-13 — Contribution-limit advisory tracker is missing.**
  Spec §5 calls out limits the engine should know to power "you have $X 401(k) headroom" insights:
  - **TY 2026:** 401(k) elective $24,500 (age 50+ catch-up $8,000; **age 60-63 enhanced $11,250**); IRA $7,500 ($1,000 catch-up); HSA self $4,400 / family $8,750 ($1,000 catch-up at 55+).
  - **TY 2025:** 401(k) $23,500 / catch-up $7,500 / age 60-63 $11,250; IRA $7,000 / $1,000 catch-up; HSA self $4,300 / family $8,550.
  Surface as advisory only — never compute someone's "after contribution" tax without a confirmed contribution event.

### LOW

- [ ] **TAX-14 — `TaxEstimate` result schema is missing `assumptions`, `warnings`, `exclusions`, `disclaimerKey`, `rulesLastUpdated`.**
  Spec §3.6 / §4.6 require these so the UI can show *why* a number came out a certain way and link to the disclaimer copy. Add to [Vittora/Core/Domain/Entities/TaxEntity.swift](Vittora/Core/Domain/Entities/TaxEntity.swift) (`TaxEstimate`) and persist on the SwiftData record so historical estimates remain interpretable after rule sets change.

- [ ] **TAX-15 — Disclaimer copy + UI gating per spec §8.**
  Add localized strings keyed `tax.disclaimer.in.v1` and `tax.disclaimer.us.v1`, present them via a non-dismissable footer on every tax screen, and gate the first use behind an "I understand this is an estimate" acknowledgement persisted on `TaxProfile`.

- [ ] **TAX-16 — Update docstrings & file headers.** Both calculator files state "FY 2024-25" / "tax year 2024" — update once tables are corrected and the rule provider lands.

---

# 2A. Recommended Tax Engine Architecture

> The attached spec [`Vittora_Tax_Engine_Rules_India_US_2026.md`](../Prompts/Vittora_Tax_Engine_Rules_India_US_2026.md) was independently web-validated against IRS Rev. Proc. 2025-32, the OBBBA standard-deduction notice, and Finance Act 2025 / §115BAC / §87A. **All numeric tables in the spec match the authoritative sources as of 2026-04-18 and the spec is adopted as the target architecture for the tax engine.** Implementing TAX-01 … TAX-16 should be done *on top of* this architecture, not by patching the existing single-file calculators.

### ARCH-T1 — Introduce a versioned `TaxRuleProvider` and immutable `TaxRuleSet`

Replace `USTaxCalculator` / `IndiaTaxCalculator` with:

```swift
// Foundation layer (Sendable, Codable, value types only).
public struct TaxRuleSet: Sendable, Codable, Identifiable {
    public let id: String                 // "US_FEDERAL_TY2026", "IN_FY2025_26_AY2026_27"
    public let jurisdiction: TaxJurisdiction
    public let taxYearLabel: String       // "TY 2026", "FY 2025-26 (AY 2026-27)"
    public let effectiveFrom: Date
    public let rulesLastUpdated: Date
    public let standardDeductions: [FilingStatus: Decimal]
    public let brackets: [FilingStatus: [TaxSlab]]
    public let rebate: RebateRule?
    public let surcharge: [SurchargeTier]
    public let cessRate: Decimal?
    public let specialRates: SpecialRateTable
    public let contributionLimits: ContributionLimits
    public let disclaimerKey: String
}

public protocol TaxRuleProviding: Sendable {
    func ruleSet(id: String) throws -> TaxRuleSet
    func availableRuleSets(for: TaxJurisdiction) -> [TaxRuleSet]
}
```

Initial provider implementation: a `BundledTaxRuleProvider` that loads JSON rule sets from the app bundle — making it trivial to ship a hot-fix update via TestFlight without touching engine code. Future option: a CloudKit-pulled `RemoteTaxRuleProvider` (still Apple-only, satisfies Rule 10).

### ARCH-T2 — Engine takes a `TaxRuleSet`, not hardcoded values

```swift
public protocol TaxEngine: Sendable {
    func estimate(profile: TaxProfile, using rules: TaxRuleSet) throws -> TaxEstimateResult
}
```

`USTaxEngine` and `IndiaTaxEngine` become pure functions of `(profile, rules)` → result. Easier to test, easier to year-bump, and removes the need for `if year == 2025` branches inside the calculator.

### ARCH-T3 — `TaxEstimateResult` carries provenance

Per spec §3.6 / §4.6:

```swift
public struct TaxEstimateResult: Sendable, Codable {
    public let total: Decimal
    public let lineItems: [TaxLineItem]   // includes federalIncomeTax, fica, niit, surcharge, cess…
    public let assumptions: [String]      // "Salaried; standard deduction applied"
    public let warnings: [String]         // "Income near §87A marginal-relief boundary"
    public let exclusions: [String]       // "Does not include state tax, AMT, FBAR…"
    public let disclaimerKey: String      // "tax.disclaimer.us.v1"
    public let ruleSetID: String
    public let rulesLastUpdated: Date
    public let computedAt: Date
}
```

Persist this on the `SDTaxEstimate` SwiftData model so a historical estimate remains explainable after a year-end rule update.

### ARCH-T4 — Wire-up checklist for the implementing agent

1. Create `Sources/Domain/Tax/TaxRuleSet.swift`, `TaxRuleProviding.swift`, `TaxEngine.swift`.
2. Create `Sources/Infrastructure/Tax/Rules/{US_FEDERAL_TY2025,US_FEDERAL_TY2026,IN_FY2025_26_AY2026_27}.json` with the numbers from spec §3 / §4 (also tabled above in TAX-01/03/04).
3. Create `BundledTaxRuleProvider` that decodes those JSON files at startup and caches them.
4. Replace `USTaxCalculator` / `IndiaTaxCalculator` with `USTaxEngine` / `IndiaTaxEngine` consuming `TaxRuleSet`.
5. Add `TaxRuleResolver` that maps `(jurisdiction, profile.financialYear)` → rule-set ID and surfaces a clear error if no rule set exists for that year (refuses to silently fall back).
6. Update `TaxDashboardViewModel` to display `assumptions`, `warnings`, `exclusions`, and the disclaimer.
7. Port every test in spec §6 (US filing-status matrix; India §87A boundary cases at ₹12,00,000 / ₹12,10,000 / ₹12,75,000; surcharge thresholds; cess application).
8. Delete the old single-file calculators and their stale tests in the same PR — no compatibility shim (per project convention: "No backwards-compatibility hacks").

---

# 3. Reliability & crash safety

### CRITICAL

- [ ] **REL-01 — `memberIDs.last!` on potentially-empty array.**
  **File:** [Vittora/Core/Domain/UseCases/AddGroupExpenseUseCase.swift:81 and 111](Vittora/Core/Domain/UseCases/AddGroupExpenseUseCase.swift)
  ```swift
  guard let lastID = memberIDs.last else {
      throw VittoraError.invalidInput("Split group has no members")
  }
  shares.append(SplitShare(memberID: lastID, amount: remainder))
  ```

- [ ] **REL-02 — Direct `accounts[0]` / `relevantCategories[0]` subscripting.**
  **File:** [Vittora/Features/Transactions/Views/TransactionFormView.swift:300, 305](Vittora/Features/Transactions/Views/TransactionFormView.swift)
  Replace with `if let first = accounts.first { vm.selectedAccountID = first.id }`.

- [ ] **REL-03 — Empty `catch {}` swallows tax-profile save failures.**
  **File:** [Vittora/Features/Tax/Views/TaxProfileFormView.swift:41](Vittora/Features/Tax/Views/TaxProfileFormView.swift)
  Surface the error on the view model and present an alert before dismiss.

### HIGH

- [ ] **REL-04 — No `SchemaMigrationPlan`.**
  **File:** [Vittora/Core/Data/Persistence/ModelContainerConfig.swift](Vittora/Core/Data/Persistence/ModelContainerConfig.swift) (the `Migrations/` folder contains only `.gitkeep`).
  Wrap every `@Model` in a `VersionedSchema` (start with `VittoraSchemaV1`), declare `enum VittoraMigrationPlan: SchemaMigrationPlan { static var schemas = [VittoraSchemaV1.self] }`, and pass it to `ModelContainer(for:migrationPlan:configurations:)`. Without this, the **first** schema change (which SEC-02 will require) will crash every existing user on launch.

- [ ] **REL-05 — Division-by-zero in budget math.**
  **Files:**
  - [Vittora/Core/Domain/UseCases/CalculateBudgetProgressUseCase.swift:58](Vittora/Core/Domain/UseCases/CalculateBudgetProgressUseCase.swift) (`spent / Decimal(daysPassed)`)
  - [Vittora/Features/Budgets/Views/BudgetDetailView.swift:120](Vittora/Features/Budgets/Views/BudgetDetailView.swift)
  - [Vittora/Core/Domain/UseCases/CalculateSubscriptionCostUseCase.swift:52](Vittora/Core/Domain/UseCases/CalculateSubscriptionCostUseCase.swift)
  Guard with `let denom = max(1, ...)` or early-return when zero.

- [ ] **REL-06 — Untracked `Task {}` in `onDisappear`.**
  **File:** [Vittora/Features/Budgets/Views/BudgetDetailView.swift:189-193](Vittora/Features/Budgets/Views/BudgetDetailView.swift)
  Store the task in `@State` and cancel before reissuing. Same pattern review needed across all `onDisappear` / `onAppear` blocks (use `.task(id:)` instead where possible).

- [ ] **REL-07 — Wholesale `try?` swallowing.**
  ~24 occurrences. Categorize each: (a) acceptable when result genuinely doesn't matter (e.g., scheduling a haptic), (b) replace with `do/catch` and route to `viewModel.error`. The full list:
  - [Vittora/Features/Splits/Views/SplitGroupFormView.swift:96](Vittora/Features/Splits/Views/SplitGroupFormView.swift)
  - [Vittora/Features/Debt/Views/SettlementFormView.swift:71](Vittora/Features/Debt/Views/SettlementFormView.swift)
  - [Vittora/Features/Debt/Views/DebtFormView.swift:88](Vittora/Features/Debt/Views/DebtFormView.swift)
  - [Vittora/Core/Security/AppLockService.swift:59](Vittora/Core/Security/AppLockService.swift)
  - [Vittora/Features/Documents/Views/DocumentListView.swift:65](Vittora/Features/Documents/Views/DocumentListView.swift)
  - [Vittora/Features/Documents/Views/DocumentImportView.swift:69, 84](Vittora/Features/Documents/Views/DocumentImportView.swift)
  - [Vittora/Features/Categories/Views/CategoryDetailView.swift:33](Vittora/Features/Categories/Views/CategoryDetailView.swift)
  - [Vittora/Features/Documents/Views/ReceiptScannerView.swift:95, 119](Vittora/Features/Documents/Views/ReceiptScannerView.swift)
  - [Vittora/Core/Security/EncryptionService.swift:35](Vittora/Core/Security/EncryptionService.swift) **← critical: a silent decrypt failure must surface**
  - [Vittora/Features/Savings/Views/SavingsGoalDetailView.swift:59](Vittora/Features/Savings/Views/SavingsGoalDetailView.swift)
  - [Vittora/Features/Recurring/Views/RecurringFormView.swift:294, 301, 356](Vittora/Features/Recurring/Views/RecurringFormView.swift)
  - [Vittora/Core/Infrastructure/ReceiptParserService.swift:48, 73, 107](Vittora/Core/Infrastructure/ReceiptParserService.swift)
  - [Vittora/Core/Data/Persistence/DataExportService.swift:104, 108, 112](Vittora/Core/Data/Persistence/DataExportService.swift)
  - [Vittora/Core/Data/Models/SDGroupExpense.swift:65, 72](Vittora/Core/Data/Models/SDGroupExpense.swift)
  - [Vittora/Core/Data/Models/SDRecurringRule.swift:47-60](Vittora/Core/Data/Models/SDRecurringRule.swift)
  - [Vittora/Core/Data/Models/SDTaxProfile.swift:62](Vittora/Core/Data/Models/SDTaxProfile.swift)
  - [Vittora/Core/Data/Models/SDSplitGroup.swift:35](Vittora/Core/Data/Models/SDSplitGroup.swift)

### MEDIUM

- [ ] **REL-08 — Hardcoded day counts in subscription/budget projections** ([Vittora/Core/Domain/UseCases/CalculateSubscriptionCostUseCase.swift:41](Vittora/Core/Domain/UseCases/CalculateSubscriptionCostUseCase.swift), `4.33` weeks/month). Use `Calendar.current.dateComponents([.day], from:to:)` instead.
- [ ] **REL-09 — Hardcoded `"USD"` currency code in 30+ views.** Centralize via `EnvironmentValue`. (See UX-02 below for the full list / fix.)
- [ ] **REL-10 — `FetchDescriptor` with no `fetchLimit` or `relationshipKeyPathsForPrefetching`.** Combined with PERF-01/02 this is what causes the report views to blow memory.
- [ ] **REL-11 — `print(...)` in production paths** ([Vittora/Core/Infrastructure/BackgroundTaskScheduler.swift:50, 62, 65](Vittora/Core/Infrastructure/BackgroundTaskScheduler.swift)). Use `os.Logger`.

### LOW

- [ ] **REL-12 — `debugPrint` in `VittoraApp` startup error paths** (lines 163, 170, 190, 210). These are stripped in Release, but the underlying issue is that startup errors aren't propagated. Wrap with `Logger.error` and consider a one-time non-fatal alert in Debug.
- [ ] **REL-13 — Mocking JSON via `try?` inside `@Model` accessors** can silently corrupt persistence. Add at least an `os.Logger.warning` on the failure branch.

---

# 4. Architecture & code quality (CLAUDE.md compliance)

The 14 architecture rules in `CLAUDE.md` are met for **10 of 14** (great): no force-unwraps in source, no `@StateObject`, no Combine, layer isolation clean, Sendable disciplined, NavigationStack throughout, 946 uses of `String(localized:)`, no third-party imports, naming consistent. Violations:

### HIGH

- [ ] **ARCH-01 — Singleton `HapticService.shared`.** Violates Rule 13.
  **File:** [Vittora/Core/Infrastructure/HapticService.swift:12](Vittora/Core/Infrastructure/HapticService.swift)
  Inject through `DependencyContainer` and pass via `@Environment` (define an `EnvironmentKey`). Update every `HapticService.shared.x()` call site (ripgrep `HapticService.shared`).

- [ ] **ARCH-02 — 24 `try?` silent failures.** Same list as REL-07. This violates Rule 14 but the fix-by-fix policy is the same: route through `Result` or `do/catch` and propagate to view-model state.

- [ ] **ARCH-03 — Manual filtering in domain layer.** Violates Rule 6.
  **File:** [Vittora/Core/Domain/UseCases/FetchDebtLedgerUseCase.swift:23-38](Vittora/Core/Domain/UseCases/FetchDebtLedgerUseCase.swift)
  Push the filter into `SwiftDataDebtRepository.fetchOutstanding()` using `#Predicate` so the database does the work.

### MEDIUM

- [ ] **ARCH-04 — 17 escaping-closure callbacks** in views/components instead of async. Violates Rule 5. Examples: [Vittora/Features/Splits/Views/AddGroupExpenseView.swift:9](Vittora/Features/Splits/Views/AddGroupExpenseView.swift), [Vittora/Features/Tax/Views/TaxProfileFormView.swift:11](Vittora/Features/Tax/Views/TaxProfileFormView.swift), and the full list in the architecture review (`onSaved`, `onApply`, `onCreateTransaction`, `onCapture`, `transform`, `action` in `View+Navigation.swift` and `VActionButton.swift`). Convert form submits to `async throws` methods on the view model; for purely visual callbacks (e.g., `VActionButton.action`) this is acceptable SwiftUI idiom and can stay.

### LOW

- [ ] **ARCH-05 — `@Index` / `@Unique` missing across all `@Model` types.** See PERF-04 for the concrete decoration plan.

---

# 5. UX, HIG and accessibility

### CRITICAL

- [ ] **UX-01 — Hardcoded English strings.** ~40 occurrences. Examples (full list in the UX section of the original review):
  - [Vittora/Features/Payees/Views/PayeeFormView.swift:21, 27, 30, 59, 63, 67, 73, 74, 77, 82, 92, 101, 102](Vittora/Features/Payees/Views/PayeeFormView.swift)
  - [Vittora/Features/Payees/Components/PayeePickerView.swift:22](Vittora/Features/Payees/Components/PayeePickerView.swift)
  - [Vittora/Features/Payees/Components/PayeeAnalyticsCard.swift:10, 18, 24, 30, 40](Vittora/Features/Payees/Components/PayeeAnalyticsCard.swift)
  - [Vittora/Features/Payees/Components/PayeeRowView.swift:22](Vittora/Features/Payees/Components/PayeeRowView.swift)
  - [Vittora/Features/Transactions/Components/DateRangePickerView.swift:38, 45, 66](Vittora/Features/Transactions/Components/DateRangePickerView.swift)
  - [Vittora/Features/Settings/Views/SettingsSectionViews.swift:162, 169, 172](Vittora/Features/Settings/Views/SettingsSectionViews.swift)
  Wrap each with `String(localized:)` and add the keys to `Vittora/Localizable.xcstrings`.

- [ ] **UX-02 — Hardcoded `"$"` and hardcoded `"USD"`.**
  **Files:**
  - [Vittora/Features/Debt/Views/DebtFormView.swift:32](Vittora/Features/Debt/Views/DebtFormView.swift)
  - [Vittora/Features/Debt/Views/SettlementFormView.swift:24, 104](Vittora/Features/Debt/Views/SettlementFormView.swift)
  - [Vittora/Features/Splits/Views/AddGroupExpenseView.swift:74, 136, 170](Vittora/Features/Splits/Views/AddGroupExpenseView.swift)
  - [Vittora/Features/Transactions/Views/TransactionFormView.swift:29](Vittora/Features/Transactions/Views/TransactionFormView.swift)
  - [Vittora/Features/Transactions/Components/AmountInputView.swift:13](Vittora/Features/Transactions/Components/AmountInputView.swift)
  - [Vittora/Features/Reports/Views/CustomReportView.swift:165](Vittora/Features/Reports/Views/CustomReportView.swift)
  Define an `EnvironmentValues.currencyCode` key (read from the user's setting, default `Locale.current.currency?.identifier ?? "USD"`) and an `EnvironmentValues.currencySymbol` key. Replace every literal `"$"` with `Text(currencySymbol)`, every literal `"USD"` with `currencyCode`. Use `.formatted(.currency(code: currencyCode))` for `Decimal` rendering.

- [ ] **UX-03 — Decorative/semantic icons missing accessibility labels.** ~15 files. Pattern:
  ```swift
  Image(systemName: "building.2.fill")
      .accessibilityLabel(String(localized: "Business payee"))
  ```
  Or, when truly decorative, `.accessibilityHidden(true)`. Hot spots:
  - [Vittora/Features/Payees/Components/PayeeRowView.swift:12, 37](Vittora/Features/Payees/Components/PayeeRowView.swift)
  - [Vittora/Features/Settings/Views/SettingsSectionViews.swift:189](Vittora/Features/Settings/Views/SettingsSectionViews.swift)
  - [Vittora/Features/Tax/Components/TaxSummaryCard.swift:23](Vittora/Features/Tax/Components/TaxSummaryCard.swift)
  - All `Image(systemName: "chevron.right")` (mark hidden — VoiceOver already announces "button").

- [ ] **UX-04 — Color-only signals (red/green) for budget state and income/expense.**
  Affected: dashboard budget bar, `IncomeExpenseBarChart`, `SavingsProgressRingView`. Add a symbol or text adjacent to color (e.g., `arrow.down.right.circle` for expense, `arrow.up.right.circle` for income) and pass through to `accessibilityValue`.

### HIGH

- [ ] **UX-05 — Missing `.textContentType` / `.keyboardType`** on email/phone/amount fields. Fix at every `TextField` site; for amounts: `.keyboardType(.decimalPad)` + `.textContentType(.none)`.
- [ ] **UX-06 — `.lineLimit(1)` + `.minimumScaleFactor` on text labels** breaks Dynamic Type / Larger Accessibility Sizes. ~20 sites. Use:
  ```swift
  @Environment(\.dynamicTypeSize) var typeSize
  Text(label).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
  ```
- [ ] **UX-07 — Animations not gated by `accessibilityReduceMotion`.** Apply at every `.animation(...)` site. Onboarding `TabView`, dashboard progress springs, savings ring.
- [ ] **UX-08 — Modal pattern: TransactionForm uses `.sheet` on iPhone with a nested `NavigationStack`.** Use `.fullScreenCover` on iPhone via `#if os(iOS)`, keep `.sheet` for iPad/Mac. Remove the inner `NavigationStack` when the sheet wraps another stack.
- [ ] **UX-09 — Empty / loading / error states inconsistent.** Many list views (`ReportsHomeView`, `DebtLedgerView`, `SplitGroupListView`, `RecurringListView`) lack `ContentUnavailableView` (or your `VEmptyState`). Audit every `List/Form/ScrollView` that depends on `vm.items` and add the three states.
- [ ] **UX-10 — Form validation messages aren't grouped for VoiceOver.** Wrap inline errors in `.accessibilityElement(children: .combine)` and announce via `.accessibilityValue`. Also consider `AccessibilityNotification.Announcement` posted on validation failure.
- [ ] **UX-11 — Settings missing finance-required controls:** explicit Export schedule, Backup status, Account-deletion flow with hard confirmation, granular notification controls (per-feature toggles for Recurring, Budget over-spend, Sync issue), passcode-fallback toggle.
- [ ] **UX-12 — Charts have no audio chart descriptors.** Use `.accessibilityChartDescriptor` on every Swift Charts view (`IncomeExpenseBarChart`, spending trends, category breakdown, tax comparison).
- [ ] **UX-13 — VoiceOver rotor / focus order on cards.** `PayeeRowView`, `HeroSpendingCard`, `BudgetCardView` should set `.accessibilityElement(children: .combine)` so the user navigates by row, not by inner element.

### MEDIUM

- [ ] **UX-14 — Hardcoded `.font(.system(size:))`** at e.g. [Vittora/DesignSystem/Components/VProgressBar.swift:12](Vittora/DesignSystem/Components/VProgressBar.swift), [Vittora/Features/Onboarding/Views/OnboardingView.swift:127](Vittora/Features/Onboarding/Views/OnboardingView.swift). Add tokens to `VTypography` and use them.
- [ ] **UX-15 — `VColors` is missing semantic state colors** (`errorBackground`, `successBackground`, `warningBackground`). Add and adopt.
- [ ] **UX-16 — Toolbar placement inconsistencies between iPhone / iPad / Mac.** Standardize: nav-bar leading for sync, nav-bar trailing for "Add", `bottomBar` for primary actions on iPhone, `automatic` for Mac.
- [ ] **UX-17 — Sidebar/tab-bar adaptation.** Confirm `NavigationSplitView` is used on `regular` width classes (iPad portrait, Mac); the current setup may always force a `TabView` on iPad.
- [ ] **UX-18 — `UserDefaults`-stored currency** is read directly in views with `??\"USD\"`. Centralize (see UX-02).
- [ ] **UX-19 — Onboarding has no biometric/app-lock prompt.** First-run UX should offer to enable Face ID / passcode app-lock.
- [ ] **UX-20 — App lock view lacks "Use passcode" affordance.** See SEC-06.
- [ ] **UX-21 — No `.refreshable` on dashboards/lists.** Add for parity with iOS norms.

### LOW

- [ ] **UX-22 — macOS Commands menu missing.** Add `.commands { CommandGroup(replacing: .newItem) { … } }` for New Transaction (`⌘N`), New Account, Save (`⌘S` in forms), Export (`⌘E`), Settings (`⌘,`).
- [ ] **UX-23 — macOS keyboard shortcuts on primary buttons.** `.keyboardShortcut("s", modifiers: .command)` on Save buttons.
- [ ] **UX-24 — Window state restoration** on macOS (use `SceneStorage`).
- [ ] **UX-25 — `ContentUnavailableView` (iOS 17+) where you currently use a custom `VEmptyState`** — keep `VEmptyState` as a wrapper but consider switching internals.
- [ ] **UX-26 — Dark-mode contrast audit.** `VColors.textTertiary` and chart palette in dark mode against the dashboard background. Hit WCAG AA at minimum (AAA preferred for finance).
- [ ] **UX-27 — Haptics on key actions** (`SensoryFeedback.success` on save, `.warning` on overspend) — already has a `HapticService`, just adopt at call sites consistently.
- [ ] **UX-28 — Search**: `TransactionListView` should have `.searchable(text:)` with token suggestions.
- [ ] **UX-29 — Sheet presentation detents** (`.medium`/`.large`) for filter / quick-entry sheets on iPhone.
- [ ] **UX-30 — Liquid-glass-ready material backgrounds** (`.regularMaterial`, `.thinMaterial`) on cards above content for the iOS 26 / macOS 15 visual language; the design system should define these tokens.

---

# 6. Performance & memory

### CRITICAL

- [ ] **PERF-01 — Dashboard fetches *all* transactions.**
  **File:** [Vittora/Core/Domain/UseCases/DashboardDataUseCase.swift:37](Vittora/Core/Domain/UseCases/DashboardDataUseCase.swift)
  Replace `fetchAll(filter: nil)` with a date-range filter for the current month. For the "year-to-date" tile, fetch a separate aggregated query (`#Predicate` for this calendar year) — never both.

- [ ] **PERF-02 — Monthly Overview fetches all transactions.**
  **File:** [Vittora/Core/Domain/UseCases/MonthlyOverviewUseCase.swift:21](Vittora/Core/Domain/UseCases/MonthlyOverviewUseCase.swift)
  Bound to `[12 months back ... now]`.

- [ ] **PERF-03 — Spending Trends & Category Breakdown have no aggregation.**
  **Files:** [Vittora/Core/Domain/UseCases/SpendingTrendsUseCase.swift:30](Vittora/Core/Domain/UseCases/SpendingTrendsUseCase.swift), [Vittora/Core/Domain/UseCases/CategoryBreakdownUseCase.swift:21](Vittora/Core/Domain/UseCases/CategoryBreakdownUseCase.swift)
  Bin server-side: daily for ≤90 days, weekly for ≤365 days, monthly otherwise. Cap chart series length.

### HIGH

- [ ] **PERF-04 — Add `@Index` / `@Unique` to all `@Model` types.**
  Recommended decoration:
  - `SDTransaction`: `@Unique var id`, `@Index var date`, `@Index var accountID`, `@Index var categoryID`, `@Index var payeeID`, `@Index var typeRawValue`.
  - `SDAccount`: `@Unique var id`, `@Index var typeRawValue`, `@Index var isArchived`.
  - `SDBudget`: `@Unique var id`, `@Index var period`, `@Index var startDate`.
  - `SDCategory`: `@Unique var id`, `@Index var typeRawValue`.
  - `SDDocument`: `@Unique var id`, `@Index var transactionID`.
  - `SDDebtEntry`: `@Unique var id`, `@Index var counterpartyID`, `@Index var isSettled`.
  - `SDRecurringRule`: `@Unique var id`, `@Index var nextRunDate`.
  Couple this with REL-04 (`SchemaMigrationPlan`) — adding `@Unique` is a destructive schema change.

- [ ] **PERF-05 — Repository post-fetch in-memory filters.**
  **File:** [Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift:21-90](Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift)
  Build the predicate composition dynamically (or expose narrow methods like `fetchByAccount(_:dateRange:)`) so all filter dimensions are pushed to SQLite.

- [ ] **PERF-06 — Search loads all transactions.**
  **File:** [Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift:151-162](Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift)
  Use `#Predicate { $0.note?.localizedStandardContains(query) == true }` and `descriptor.fetchLimit = 100`. Debounce the search field on the view side (`.task(id: query)` + 250ms sleep).

- [ ] **PERF-07 — `bulkDelete` saves per item.**
  **File:** [Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift:145-149](Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift)
  Loop the deletes inside one context, then a single `try modelContext.save()` at the end.

- [ ] **PERF-08 — `NumberFormatter` allocated in `body`.**
  - [Vittora/DesignSystem/Components/VAmountText.swift:76-86](Vittora/DesignSystem/Components/VAmountText.swift)
  - [Vittora/Features/Dashboard/Components/HeroSpendingCard.swift:112-115](Vittora/Features/Dashboard/Components/HeroSpendingCard.swift)
  - [Vittora/Features/Reports/Views/SpendingTrendsView.swift:127-133](Vittora/Features/Reports/Views/SpendingTrendsView.swift)
  Prefer `Decimal.formatted(.currency(code: currencyCode))` (free, no allocation) — that should eliminate every `NumberFormatter` in the project.

- [ ] **PERF-09 — `DateFormatter` allocated per-row.**
  **File:** [Vittora/Features/Transactions/Components/TransactionRowView.swift:82-86](Vittora/Features/Transactions/Components/TransactionRowView.swift)
  Use `Date.FormatStyle` (`date.formatted(date: .omitted, time: .shortened)`) or hold a static formatter on the view.

- [ ] **PERF-10 — `Calendar.current` re-resolved inside loops.**
  Cache once outside the loop in `SpendingTrendsUseCase`, `DashboardDataUseCase`, `Date+Formatting`.

- [ ] **PERF-11 — Redundant `Task` in `onAppear` alongside `.task`.**
  **File:** [Vittora/Features/Transactions/Views/TransactionListView.swift:33-38](Vittora/Features/Transactions/Views/TransactionListView.swift)
  Remove the `onAppear` block; `.task` handles initial load and cancellation.

### MEDIUM

- [ ] **PERF-12 — `FetchDescriptor.fetchLimit` missing on lists** ([Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift:6-18](Vittora/Core/Data/Repositories/SwiftDataTransactionRepository.swift)). Paginate; the UI never needs >200 rows in memory.
- [ ] **PERF-13 — `NSDecimalNumber` round-trip** in [Vittora/Core/Domain/UseCases/DashboardDataUseCase.swift:100-102](Vittora/Core/Domain/UseCases/DashboardDataUseCase.swift). Compute the ratio in `Decimal`, convert to `Double` once at the very last step.
- [ ] **PERF-14 — Repository should accept partial predicates** so callers (`FetchDebtLedgerUseCase`, `FetchOverdueDebtsUseCase`) can filter at SQLite level.

### LOW

- [ ] **PERF-15 — Calendar-heavy `Date` extensions** ([Vittora/Core/Extensions/Date+Formatting.swift:53-173](Vittora/Core/Extensions/Date+Formatting.swift)) re-create `Calendar.current` multiple times per call. Cache once per file.

---

# 7. Test coverage gaps

Currently 41 test files / ~347 tests, but the highest-risk layers have nearly zero coverage:

| Layer | Files | Tested | Status |
|---|---:|---:|---|
| Domain use cases | 51 | 28 | **HIGH GAP** |
| `SwiftData…Repository` | 11 | 0 | **CRITICAL GAP** |
| Mappers | 11 | 2 | **CRITICAL GAP** |
| View models | 40 | 6 | **CRITICAL GAP** |
| Tax calculators | 2 | 2 | OK (but tests must be re-validated against TAX-01/02/03 fixes) |
| Encryption / Keychain | 2 | 2 | OK |
| `AppLockService` / `BiometricService` | 2 | 0 | **HIGH GAP** |
| `SchemaMigrationPlan` | — | 0 | (only valid once REL-04 lands) |

### Required test additions (priority order)

- [ ] **TST-01 — Repository integration tests for all 11 SwiftData repos.** Use the existing in-memory `ModelContainer` helper. Cover: insert, fetch by predicate, sort, relationships, cascade delete, bulk operations.
- [ ] **TST-02 — Mapper round-trip tests for the 9 missing mappers** (Budget, Category, Debt, Document, Payee, RecurringRule, SavingsGoal, SplitGroup, TaxProfile). Assert all fields survive `entity → SD → entity`.
- [ ] **TST-03 — `AppLockService` tests** (lock state transitions, timeout, foreground/background, passcode-fallback path).
- [ ] **TST-04 — `BiometricService` tests** (LAContext mock, lockout fallback to passcode).
- [ ] **TST-05 — `SchemaMigrationPlan` tests** (write a V1 store, open as V2, assert data preserved). One test per migration step you ship.
- [ ] **TST-06 — Tax calculator regression suite** for **each supported year**: bracket boundaries (income exactly at threshold), zero income, income above max surcharge tier, marginal-relief edge cases, MFJ/MFS/HoH/Single, Old vs New regime, senior/super-senior, LTCG only, salary + LTCG mix.
- [ ] **TST-07 — View model tests** for at minimum: `TransactionFormViewModel`, `BudgetDetailViewModel`, `DashboardViewModel`, `ReportsHomeViewModel`, `SettingsViewModel`, `TaxProfileFormViewModel`, `SubscriptionSummaryViewModel`. State + error paths.
- [ ] **TST-08 — Use-case tests** for the entire **Debt** (6), **Splits** (4), **Documents** (5), **Reports** (5), and **Transactions advanced** (Search/Update/Delete/Transfer/Bulk/DuplicateDetection/SmartCategorize) families.
- [ ] **TST-09 — Sync conflict tests**: simulate amount divergence, currency mismatch, deleted-on-one-side, simultaneous edits — assert resolution behaviour from SEC-09.
- [ ] **TST-10 — UI tests** for: lock/unlock flow, sync error banner, tax-profile creation, budget overspend warning. Currently the UI test target uses XCTest — keep that (Swift Testing doesn't support UI tests yet).

### Test quality fixes (must do before adding new tests)

- [ ] **TST-Q1 — `UserDefaults.standard` pollution.** [VittoraTests/Core/Sync/SyncStatusServiceTests.swift:41, 73](VittoraTests/Core/Sync/SyncStatusServiceTests.swift). Inject a `UserDefaults(suiteName: "com.vittora.test.\(UUID())")` per test.
- [ ] **TST-Q2 — `.now` / `Calendar.current` in tests** ([VittoraTests/Features/Budgets/BudgetUseCaseTests.swift:176, 289](VittoraTests/Features/Budgets/BudgetUseCaseTests.swift), [VittoraTests/Features/Recurring/RecurringUseCaseTests.swift:50](VittoraTests/Features/Recurring/RecurringUseCaseTests.swift), [VittoraTests/Features/Tax/TaxUseCaseTests.swift:261-264](VittoraTests/Features/Tax/TaxUseCaseTests.swift)). Inject a fixed `Calendar(identifier: .gregorian)` and a `Clock` (e.g., a `nowProvider: () -> Date` parameter on use cases).
- [ ] **TST-Q3 — Empty `catch {}` / trivial assertions** in [VittoraTests/VittoraTests.swift](VittoraTests/VittoraTests.swift) (`#expect(!tab.title.isEmpty)`). Replace with meaningful behaviour assertions.
- [ ] **TST-Q4 — Add missing mocks** (`MockDebtRepository`, `MockDocumentRepository`, `MockSplitGroupRepository`, `MockTaxProfileRepository`, `MockAppLockService`) under `VittoraTests/Core/Mocks/` so tests stop redefining ad-hoc stubs inline.

---

# 8. Offline & no-3rd-party verification

Both constraints largely **pass**:

- ripgrep finds **zero** `URLSession` / `URLRequest` / external HTTP calls in the source tree. Only Apple frameworks are imported. The only "network" pathway is CloudKit, which is allowed.
- SwiftData writes succeed offline (verified by `SyncStatusService` flow at [Vittora/Core/Sync/SyncStatusService.swift:96-98](Vittora/Core/Sync/SyncStatusService.swift)). Local writes are not blocked by the offline check; sync attempt is deferred until reachability returns.

Action items:

- [ ] **OFFL-01 — Document the offline contract** in code (header comment in `SyncStatusService`): "Local writes always succeed; sync runs opportunistically when network returns; on conflict, last-writer-wins by timestamp" (after SEC-09 lands, update to reflect the new conflict policy).
- [ ] **OFFL-02 — Add a UI affordance** so the user can see pending-sync count and last successful sync timestamp (already partly exposed — make sure it works with iCloud signed out).
- [ ] **OFFL-03 — Test "iCloud signed out" path explicitly** (TST-09 covers this).

---

# 9. Info.plist / entitlements checklist

Open [Vittora/Info.plist](Vittora/Info.plist) and [Vittora/Vittora.entitlements](Vittora/Vittora.entitlements) and verify:

- [ ] `ITSAppUsesNonExemptEncryption` = `NO` (you use AES-GCM via CryptoKit — covered by exemption when purely for local data protection).
- [ ] `NSFaceIDUsageDescription` present, copy explains *why* (finance unlock).
- [ ] `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSContactsUsageDescription` present and accurate.
- [ ] `UIBackgroundModes`: only `fetch` and `remote-notification` if actually used; remove unused.
- [ ] `com.apple.developer.icloud-services` includes `CloudKit`.
- [ ] `com.apple.security.app-sandbox` (macOS) = `true`.
- [ ] `com.apple.security.files.user-selected.read-write` (macOS) for document import.
- [ ] No `NSAppTransportSecurity` exceptions (you don't make HTTP calls).

---

# 10. Suggested execution plan

Estimated: **3–4 engineering weeks** for a single full-time engineer to clear Critical + High; another 2 weeks for Medium and the test backlog.

### Week 1 — Show-stoppers (Critical only)
1. Tax engine: TAX-01 → TAX-04 (with regression test rewrite).
2. Security: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05.
3. Crashes: REL-01, REL-02, REL-03.
4. Migration plan: REL-04 (mandatory before SEC-02 ships).
5. Hardcoded currency / strings: UX-01, UX-02 (App Store blockers).
6. Performance: PERF-01, PERF-02, PERF-03 (otherwise dashboard freezes on real datasets).
7. UX: UX-03, UX-04 (App Store accessibility blocker).

### Week 2 — High-severity
- All remaining HIGH items in Security (SEC-06..SEC-12), Reliability (REL-05..REL-07), UX (UX-05..UX-13), Performance (PERF-04..PERF-11), Architecture (ARCH-01..ARCH-03), Tax (TAX-05..TAX-07).
- Set up `SchemaMigrationPlan` with V1; add migration for SEC-02's encrypted-blob change.

### Week 3 — Medium + tests
- All MEDIUM items.
- Test additions TST-Q1..TST-Q4, TST-01..TST-05.

### Week 4 — Low + polish + release prep
- LOW items, macOS commands, dark-mode contrast pass.
- TST-06..TST-10.
- Full TestFlight cycle with Accessibility Inspector + VoiceOver smoke pass.
- `xcodebuild test` clean, `xcodebuild archive` clean for both platforms.

---

# 11. Quick verification grep commands

After fixes land, these should all return empty (or only intended exceptions):

```bash
# No force-unwraps in source
rg -n '!\s*$|!\s*[\.\[]' Vittora/Vittora --type swift -g '!**/Tests/**'
# No hardcoded $ in views
rg -n 'Text\("\$"\)' Vittora/Vittora
# No hardcoded "USD" outside Settings model and Locale defaults
rg -n '"USD"' Vittora/Vittora
# No try? in source (allow only annotated exceptions with // try?-OK comment)
rg -n 'try\?' Vittora/Vittora
# No print() in production
rg -n '^\s*print\(' Vittora/Vittora --type swift
# All NumberFormatter usage (should drop to ~0 after PERF-08)
rg -n 'NumberFormatter\(\)' Vittora/Vittora
# SwiftData @Index / @Unique present
rg -n '@(Index|Unique)' Vittora/Vittora/Core/Data/Models
# fatalError in production
rg -n 'fatalError\(' Vittora/Vittora --type swift -g '!**/Tests/**'
```

---

# 12. Sign-off checklist (DRI before TestFlight)

- [ ] All **Critical** boxes ticked, automated tests green on `xcodebuild test`.
- [ ] All **High** boxes ticked.
- [ ] Schema migration tests prove a V1-store upgrades cleanly.
- [ ] VoiceOver smoke test on iPhone, iPad and Mac (5 minutes per platform).
- [ ] Dynamic Type at "Larger Accessibility 5" — no truncation, no overlap.
- [ ] Reduce Motion + Reduce Transparency + Increase Contrast each enabled and the app remains usable.
- [ ] App lock: enable Face ID, then disable Face ID in iOS Settings → app must still let user in via passcode.
- [ ] Airplane Mode: full app usable, transactions persist, sync resumes when network returns.
- [ ] Tax dashboard: spot-check one US scenario (Single, $80k income, std deduction) and one India scenario (New Regime, ₹15L income) against an external calculator.
- [ ] Export a CSV with a note `=cmd|'/c calc'!A1` and confirm Excel does not execute.
- [ ] iCloud sign-out: app continues to work; sync state shown gracefully.
- [ ] No `print(...)`, `fatalError(...)`, or `TODO`/`FIXME` left in source per the grep checklist.

---

*End of report.*
