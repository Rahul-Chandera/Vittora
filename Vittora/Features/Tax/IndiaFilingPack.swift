import Foundation
import VittoraCore

/// A year-end summary an Indian taxpayer can hand to their CA: income by category, the
/// spending that may support a deduction, what was declared in the tax profile, and the
/// old-versus-new regime estimate. Built entirely from the user's own records.
///
/// It is a starting point, not a return. The section labels are the familiar ones from
/// the Income-tax Act, 1961; from tax year 2026-27 the Income-tax Act, 2025 renumbered
/// them, and the pack says so.
struct IndiaFilingPack: Equatable, Sendable {
    struct Line: Equatable, Sendable, Identifiable {
        let id: String
        let name: String
        let amount: Decimal
    }

    /// One transaction behind a deduction, described the way the user will recognise it.
    struct EvidenceRow: Equatable, Sendable, Identifiable {
        let id: UUID
        let date: Date
        let description: String
        let amount: Decimal
    }

    /// Spending that may support one deduction, with the transactions behind it.
    struct Evidence: Equatable, Sendable, Identifiable {
        let section: IndiaFilingSection
        let total: Decimal
        let rows: [EvidenceRow]
        var id: String { section.rawValue }
    }

    let financialYear: String
    let period: ClosedRange<Date>
    let incomeByCategory: [Line]
    let totalIncome: Decimal
    let evidence: [Evidence]
    let declaredDeductions: [Line]
    /// Old and new regime estimates, when the profile is complete enough to compute them.
    let regimeComparison: TaxComparison?
    /// Transactions in other currencies, left out of every total.
    let excludedOtherCurrencyCount: Int

    static func == (lhs: IndiaFilingPack, rhs: IndiaFilingPack) -> Bool {
        lhs.financialYear == rhs.financialYear && lhs.incomeByCategory == rhs.incomeByCategory
            && lhs.evidence == rhs.evidence && lhs.declaredDeductions == rhs.declaredDeductions
            && lhs.totalIncome == rhs.totalIncome && lhs.excludedOtherCurrencyCount == rhs.excludedOtherCurrencyCount
    }
}

/// Deductions the pack looks for evidence of, matched by keywords in the category,
/// payee and note. Matching is deliberately literal: a CA reviews every line, and a
/// keyword list the user can read is easier to trust than a guess.
enum IndiaFilingSection: String, CaseIterable, Sendable {
    case section80C, section80D, section80CCD1B, section80E, section80G, rent

    var title: String {
        switch self {
        case .section80C: String(localized: "80C: investments and insurance")
        case .section80D: String(localized: "80D: health insurance")
        case .section80CCD1B: String(localized: "80CCD(1B): NPS")
        case .section80E: String(localized: "80E: education loan interest")
        case .section80G: String(localized: "80G: donations")
        case .rent: String(localized: "Rent paid (for HRA or 80GG)")
        }
    }

    var keywords: [String] {
        switch self {
        case .section80C:
            ["ppf", "elss", "lic", "life insurance", "epf", "vpf", "tuition", "school fee", "sukanya", "nsc", "tax saver", "home loan principal"]
        case .section80D: ["health insurance", "medical insurance", "mediclaim", "preventive health", "health check"]
        case .section80CCD1B: ["nps", "national pension"]
        case .section80E: ["education loan"]
        case .section80G: ["donation", "charity"]
        case .rent: ["rent"]
        }
    }

    /// The first section whose keyword appears in the text. NPS is checked before 80C so
    /// an NPS contribution is not counted as an 80C investment.
    static func match(_ lowerText: String) -> IndiaFilingSection? {
        let order: [IndiaFilingSection] = [.section80CCD1B, .section80D, .section80E, .section80G, .section80C, .rent]
        return order.first { section in
            section.keywords.contains { keyword in
                lowerText.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: keyword) + #"\b"#, options: .regularExpression) != nil
            }
        }
    }
}

enum IndiaFilingPackBuilder {
    /// "2026-27" → 1 April 2026 ... 31 March 2027 (end of day), in the given calendar.
    static func period(forFinancialYear financialYear: String, calendar: Calendar) -> ClosedRange<Date>? {
        guard let startYear = Int(financialYear.prefix(4)),
              let start = calendar.date(from: DateComponents(year: startYear, month: 4, day: 1)),
              let next = calendar.date(from: DateComponents(year: startYear + 1, month: 4, day: 1))
        else { return nil }
        return start...next.addingTimeInterval(-1)
    }

    static func build(
        financialYear: String,
        transactions: [TransactionEntity],
        categories: [CategoryEntity],
        payees: [PayeeEntity],
        profile: TaxProfile,
        comparison: TaxComparison?,
        currencyCode: String = "INR",
        calendar: Calendar = .current
    ) -> IndiaFilingPack? {
        guard let period = period(forFinancialYear: financialYear, calendar: calendar) else { return nil }
        let inYear = transactions.filter { period.contains($0.date) }
        let counted = inYear.filter { $0.currencyCode == currencyCode }
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let payeeNames = Dictionary(payees.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        let income = counted.filter { $0.type == .income }
        let incomeLines = Dictionary(grouping: income) { $0.categoryID }
            .map { id, items in
                IndiaFilingPack.Line(
                    id: id?.uuidString ?? "uncategorized",
                    name: id.flatMap { categoryNames[$0] } ?? String(localized: "Uncategorized"),
                    amount: items.reduce(Decimal(0)) { $0 + $1.amount }
                )
            }
            .sorted { $0.amount > $1.amount }

        var bySection: [IndiaFilingSection: [IndiaFilingPack.EvidenceRow]] = [:]
        for transaction in counted where transaction.type == .expense {
            let category = transaction.categoryID.flatMap { categoryNames[$0] }
            let payee = transaction.payeeID.flatMap { payeeNames[$0] }
            let text = [category, payee, transaction.note].compactMap { $0 }.joined(separator: " ").lowercased()
            if let section = IndiaFilingSection.match(text) {
                let description = [payee ?? transaction.note, category].compactMap { $0 }.joined(separator: " · ")
                bySection[section, default: []].append(IndiaFilingPack.EvidenceRow(
                    id: transaction.id, date: transaction.date, description: description, amount: transaction.amount
                ))
            }
        }
        let evidence = IndiaFilingSection.allCases.compactMap { section -> IndiaFilingPack.Evidence? in
            guard let rows = bySection[section], !rows.isEmpty else { return nil }
            return IndiaFilingPack.Evidence(
                section: section,
                total: rows.reduce(Decimal(0)) { $0 + $1.amount },
                rows: rows.sorted { $0.date < $1.date }
            )
        }

        let declared = profile.customDeductions
            .filter { $0.amount > 0 }
            .map { IndiaFilingPack.Line(id: $0.id.uuidString, name: [$0.section, $0.name].compactMap { $0 }.joined(separator: " · "), amount: $0.amount) }

        return IndiaFilingPack(
            financialYear: financialYear,
            period: period,
            incomeByCategory: incomeLines,
            totalIncome: incomeLines.reduce(Decimal(0)) { $0 + $1.amount },
            evidence: evidence,
            declaredDeductions: declared,
            regimeComparison: comparison,
            excludedOtherCurrencyCount: inYear.count - counted.count
        )
    }
}

/// Loads a financial year's records and builds the pack.
struct IndiaFilingPackUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let payeeRepository: any PayeeRepository

    func execute(profile: TaxProfile, comparison: TaxComparison?, calendar: Calendar = .current) async throws -> IndiaFilingPack? {
        guard let period = IndiaFilingPackBuilder.period(forFinancialYear: profile.financialYear, calendar: calendar) else { return nil }
        return IndiaFilingPackBuilder.build(
            financialYear: profile.financialYear,
            transactions: try await transactionRepository.fetchAll(filter: TransactionFilter(dateRange: period)),
            categories: try await categoryRepository.fetchAll(),
            payees: try await payeeRepository.fetchAll(),
            profile: profile,
            comparison: comparison,
            calendar: calendar
        )
    }
}
