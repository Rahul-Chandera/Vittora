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
        nonisolated let allowedTotal: Decimal
        nonisolated let hraExemption: Decimal
        nonisolated let utilizations: [Utilization]
        nonisolated let warnings: [String]
    }

    nonisolated static func resolve(
        deductions: [TaxDeduction],
        advancedInputs: TaxAdvancedInputs,
        dateOfBirth: Date?,
        financialYearLabel: String,
        referenceDate: Date = .now
    ) -> Result {
        var warnings: [String] = []
        var utilizations: [Utilization] = []
        var allowedTotal: Decimal = 0

        var bucketClaims: [SectionBucket: Decimal] = [
            .section80C: 0,
            .section80CCD1B: 0,
            .section80DSelf: 0,
            .section80DParents: 0,
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

        let hraResult = hraExemption(
            advancedInputs: advancedInputs,
            deductions: deductions
        )
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

        let otherClaimed = bucketClaims[.other, default: 0]
        if otherClaimed > 0 {
            warnings.append(
                String(
                    localized: "Unsupported or uncapped deduction sections were not applied. Use 80C, 80CCD(1B), 80D, or HRA."
                )
            )
        }

        return Result(
            allowedTotal: allowedTotal,
            hraExemption: hraResult.exemption,
            utilizations: utilizations,
            warnings: warnings
        )
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

        if normalized == "HRA" {
            return .hra
        }
        if normalized.contains("80CCD1B") || normalized == "80CCD1B" {
            return .section80CCD1B
        }
        if normalized.contains("80DPARENTS") || normalized == "80DP" {
            return .section80DParents
        }
        if normalized.hasPrefix("80D") {
            return .section80DSelf
        }
        if normalized.hasPrefix("80C") {
            return .section80C
        }
        return .other
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
        guard let dateOfBirth else { return false }
        let fyStartYear = Int(financialYearLabel.prefix(4)) ?? Calendar.current.component(.year, from: referenceDate)
        // Age for 80D is assessed at FY end (31 March), not FY start.
        let fyEnd = Calendar.current.date(from: DateComponents(year: fyStartYear + 1, month: 3, day: 31)) ?? referenceDate
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: fyEnd).year ?? 0
        return age >= 60
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
