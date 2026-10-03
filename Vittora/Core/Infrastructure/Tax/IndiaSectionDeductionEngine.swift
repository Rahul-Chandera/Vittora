import Foundation
import VittoraCore

/// Section-aware old-regime deduction caps and HRA exemption (K1).
enum IndiaSectionDeductionEngine {
    nonisolated static let cap80C: Decimal = 150_000
    nonisolated static let cap80CCD1B: Decimal = 50_000
    nonisolated static let cap80DSelfRegular: Decimal = 25_000
    nonisolated static let cap80DSelfSenior: Decimal = 50_000
    nonisolated static let cap80DParentsRegular: Decimal = 25_000
    nonisolated static let cap80DParentsSenior: Decimal = 50_000

    enum SectionBucket: String, Sendable {
        case section80C
        case section80CCD1B
        case section80DSelf
        case section80DParents
        /// §80CCD(2), employer NPS. Not a personal Chapter VI-A claim: capped
        /// by salary, allowed under BOTH regimes, so it is resolved apart.
        case section80CCD2
        case hra
        case other
    }

    struct Utilization: Sendable, Identifiable {
        nonisolated var id: String { sectionKey }
        nonisolated let sectionKey: String
        nonisolated let claimed: Decimal
        nonisolated let allowed: Decimal
        nonisolated let statutoryCap: Decimal

        nonisolated var remaining: Decimal {
            max(0, statutoryCap - allowed)
        }
    }

    struct Result: Sendable {
        /// Old-regime personal deductions and HRA. Excludes `employerNPS`.
        nonisolated let allowedTotal: Decimal
        /// §80CCD(2) employer NPS allowed at the regime's salary percentage.
        nonisolated var employerNPS: Decimal = 0
        nonisolated let hraExemption: Decimal
        nonisolated let utilizations: [Utilization]
        nonisolated let warnings: [String]
    }

    nonisolated static func resolve(
        deductions: [TaxDeduction],
        advancedInputs: TaxAdvancedInputs,
        dateOfBirth: Date?,
        financialYearLabel: String,
        referenceDate: Date = .now,
        incomeSourceType: IncomeSourceType = .salaried,
        employerNPSRate: Decimal = 0
    ) -> Result {
        var warnings: [String] = []
        var utilizations: [Utilization] = []
        var allowedTotal: Decimal = 0

        var bucketClaims: [SectionBucket: Decimal] = [
            .section80C: 0,
            .section80CCD1B: 0,
            .section80DSelf: 0,
            .section80DParents: 0,
            .section80CCD2: 0,
            .other: 0,
        ]

        for deduction in deductions {
            let bucket = bucket(for: deduction.section)
            if bucket == .hra {
                continue
            }
            bucketClaims[bucket, default: 0] += max(0, deduction.amount)
        }

        let allowed80C = min(bucketClaims[.section80C, default: 0], cap80C)
        if bucketClaims[.section80C, default: 0] > cap80C {
            warnings.append(String(localized: "Section 80C claims were capped at ₹1.5 lakh."))
        }
        if bucketClaims[.section80C, default: 0] > 0 {
            utilizations.append(
                Utilization(
                    sectionKey: "80C",
                    claimed: bucketClaims[.section80C, default: 0],
                    allowed: allowed80C,
                    statutoryCap: cap80C
                )
            )
        }
        allowedTotal += allowed80C

        let allowed80CCD1B = min(bucketClaims[.section80CCD1B, default: 0], cap80CCD1B)
        if bucketClaims[.section80CCD1B, default: 0] > cap80CCD1B {
            warnings.append(String(localized: "Section 80CCD(1B) claims were capped at ₹50,000."))
        }
        if bucketClaims[.section80CCD1B, default: 0] > 0 {
            utilizations.append(
                Utilization(
                    sectionKey: "80CCD(1B)",
                    claimed: bucketClaims[.section80CCD1B, default: 0],
                    allowed: allowed80CCD1B,
                    statutoryCap: cap80CCD1B
                )
            )
        }
        allowedTotal += allowed80CCD1B

        let self80DCap = cap80D(forSelf: true, dateOfBirth: dateOfBirth, financialYearLabel: financialYearLabel, referenceDate: referenceDate)
        let allowed80DSelf = min(bucketClaims[.section80DSelf, default: 0], self80DCap)
        if bucketClaims[.section80DSelf, default: 0] > self80DCap {
            warnings.append(String(localized: "Section 80D (self/family) claims were capped at the age-based limit."))
        }
        if bucketClaims[.section80DSelf, default: 0] > 0 {
            utilizations.append(
                Utilization(
                    sectionKey: "80D",
                    claimed: bucketClaims[.section80DSelf, default: 0],
                    allowed: allowed80DSelf,
                    statutoryCap: self80DCap
                )
            )
        }
        allowedTotal += allowed80DSelf

        let parents80DCap = cap80D(
            forSelf: false,
            parentsAreSenior: advancedInputs.indiaParentsSeniorCitizen,
            dateOfBirth: dateOfBirth,
            financialYearLabel: financialYearLabel,
            referenceDate: referenceDate
        )
        let allowed80DParents = min(bucketClaims[.section80DParents, default: 0], parents80DCap)
        if bucketClaims[.section80DParents, default: 0] > parents80DCap {
            warnings.append(String(localized: "Section 80D (parents) claims were capped at the age-based limit."))
        }
        if bucketClaims[.section80DParents, default: 0] > 0 {
            utilizations.append(
                Utilization(
                    sectionKey: String(localized: "80D (Parents)"),
                    claimed: bucketClaims[.section80DParents, default: 0],
                    allowed: allowed80DParents,
                    statutoryCap: parents80DCap
                )
            )
        }
        allowedTotal += allowed80DParents

        // HRA is a salary exemption: business income cannot claim it.
        let hraResult = incomeSourceType == .salaried
            ? hraExemption(advancedInputs: advancedInputs, deductions: deductions)
            : (exemption: Decimal(0), claimedReference: Decimal(0), warnings: hraClaimed(deductions) > 0
                ? [String(localized: "HRA exemption applies to salary only, so it was not applied to business income.")]
                : [])
        allowedTotal += hraResult.exemption
        if hraResult.exemption > 0 {
            utilizations.append(
                Utilization(
                    sectionKey: "HRA",
                    claimed: hraResult.claimedReference,
                    allowed: hraResult.exemption,
                    statutoryCap: hraResult.exemption
                )
            )
        }
        warnings.append(contentsOf: hraResult.warnings)

        // Employer NPS: up to the regime's share of basic salary + DA, which is
        // the only base the statute allows. Without that salary there is no cap
        // to apply, so nothing is allowed rather than an arbitrary amount.
        var employerNPS: Decimal = 0
        let employerClaimed = bucketClaims[.section80CCD2, default: 0]
        if employerClaimed > 0 {
            let basic = advancedInputs.indiaBasicSalary
            if incomeSourceType == .salaried, basic > 0 {
                let cap = (basic * employerNPSRate).rounded(scale: 2)
                employerNPS = min(employerClaimed, cap)
                if employerClaimed > cap {
                    warnings.append(String(localized: "Employer NPS (80CCD(2)) was capped at its share of basic salary + DA."))
                }
            } else {
                warnings.append(String(localized: "Employer NPS (80CCD(2)) needs salaried income and basic salary + DA, so it was not applied."))
            }
        }

        let otherClaimed = bucketClaims[.other, default: 0]
        if otherClaimed > 0 {
            warnings.append(
                String(
                    localized: "Unsupported or uncapped deduction sections were not applied. Use 80C, 80CCD(1B), 80CCD(2), 80D, or HRA."
                )
            )
        }

        return Result(
            allowedTotal: allowedTotal,
            employerNPS: employerNPS,
            hraExemption: hraResult.exemption,
            utilizations: utilizations,
            warnings: warnings
        )
    }

    nonisolated private static func hraClaimed(_ deductions: [TaxDeduction]) -> Decimal {
        deductions.filter { bucket(for: $0.section) == .hra }.reduce(Decimal(0)) { $0 + max(0, $1.amount) }
    }

    /// Headroom left in a section this year.
    ///
    /// `resolve` only emits a `Utilization` for a section something was claimed against, so
    /// a missing entry means "nothing claimed" — the full cap is available. Reading the
    /// absent entry as zero remaining inverts the answer and tells a user with an empty 80C
    /// that they have no room left, which is how this was first shipped and caught.
    nonisolated static func remaining(
        sectionKey: String,
        cap: Decimal,
        in result: Result
    ) -> Decimal {
        let allowed = result.utilizations.first { $0.sectionKey == sectionKey }?.allowed ?? 0
        return max(0, cap - allowed)
    }

    nonisolated static func remaining80C(in result: Result) -> Decimal {
        remaining(sectionKey: "80C", cap: cap80C, in: result)
    }

    nonisolated static func remaining80CCD1B(in result: Result) -> Decimal {
        remaining(sectionKey: "80CCD(1B)", cap: cap80CCD1B, in: result)
    }

    nonisolated static func bucket(for section: String?) -> SectionBucket {
        guard let raw = section?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .other
        }
        let normalized = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "-", with: "")

        // Exact statutory identifiers. Prefix matching put 80DD/80DDB under the
        // 80D cap and employer 80CCD(2) under the 80C cap.
        switch normalized {
        case "HRA":
            return .hra
        case "80CCD1B":
            return .section80CCD1B
        case "80CCD2":
            return .section80CCD2
        case "80C", "80CCC", "80CCD1":
            // 80CCC and 80CCD(1) share the ₹1.5 lakh 80CCE ceiling with 80C.
            return .section80C
        case "80D", "80DSELF":
            return .section80DSelf
        case "80DPARENTS", "80DP":
            return .section80DParents
        default:
            return .other
        }
    }

    nonisolated static func hraExemption(
        advancedInputs: TaxAdvancedInputs,
        deductions: [TaxDeduction]
    ) -> (exemption: Decimal, claimedReference: Decimal, warnings: [String]) {
        let salary = advancedInputs.indiaBasicSalary
        let hraReceived = advancedInputs.indiaHRAPaid
        let rentPaid = advancedInputs.indiaRentPaid
        let hasStructuredInputs = salary > 0 && (hraReceived > 0 || rentPaid > 0)

        if hasStructuredInputs {
            let rentComponent = max(0, rentPaid - (salary * hraSalaryDeductionRate))
            let salaryPercent = advancedInputs.indiaMetroCity
                ? salary * hraMetroSalaryCapRate
                : salary * hraNonMetroSalaryCapRate
            let exemption = min(hraReceived, rentComponent, salaryPercent).rounded(scale: 2)
            return (exemption, hraReceived, [])
        }

        let claimedHRA = deductions
            .filter { bucket(for: $0.section) == .hra }
            .reduce(Decimal(0)) { $0 + max(0, $1.amount) }

        guard claimedHRA > 0 else {
            return (0, 0, [])
        }

        return (
            claimedHRA,
            claimedHRA,
            [String(localized: "HRA used the entered amount. Add basic salary, rent, and HRA received for the statutory minimum-of-three calculation.")]
        )
    }

    nonisolated static func cap80D(
        forSelf: Bool,
        parentsAreSenior: Bool = false,
        dateOfBirth: Date?,
        financialYearLabel: String,
        referenceDate: Date
    ) -> Decimal {
        if forSelf {
            return isSeniorCitizen(dateOfBirth: dateOfBirth, financialYearLabel: financialYearLabel, referenceDate: referenceDate)
                ? cap80DSelfSenior
                : cap80DSelfRegular
        }
        return parentsAreSenior ? cap80DParentsSenior : cap80DParentsRegular
    }

    nonisolated static func isSeniorCitizen(
        dateOfBirth: Date?,
        financialYearLabel: String,
        referenceDate: Date
    ) -> Bool {
        let fyStartYear = Int(financialYearLabel.prefix(4)) ?? Calendar.current.component(.year, from: referenceDate)
        return (IndiaTaxAge.attainedAge(dateOfBirth: dateOfBirth, financialYear: fyStartYear) ?? 0) >= 60
    }

    nonisolated private static let hraSalaryDeductionRate = Decimal(10) / Decimal(100)
    nonisolated private static let hraMetroSalaryCapRate = Decimal(50) / Decimal(100)
    nonisolated private static let hraNonMetroSalaryCapRate = Decimal(40) / Decimal(100)
}

private extension Decimal {
    nonisolated func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}

/// Age for Indian tax purposes: the age attained at any time in the financial
/// year. A person born on 1 April is treated as attaining that age on the
/// previous day (CBDT), so the reference is 1 April AFTER the year ends.
/// Used for both senior slabs and 80D, and always with the REQUESTED year, not
/// whichever rule table it resolved to.
enum IndiaTaxAge {
    nonisolated static func attainedAge(dateOfBirth: Date?, financialYear: Int) -> Int? {
        guard let dateOfBirth else { return nil }
        let birth = Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth)
        guard let year = birth.year, let month = birth.month, let day = birth.day else { return nil }
        // Compare calendar dates, not instants, so a time zone cannot move a
        // birthday across the boundary.
        let hadBirthdayByApril1 = month < 4 || (month == 4 && day <= 1)
        return financialYear + 1 - year - (hadBirthdayByApril1 ? 0 : 1)
    }
}
