import Foundation

struct GenerateTaxSummaryUseCase: Sendable {
    private let transactionRepository: any TransactionRepository
    private let fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase
    private let calendar: Calendar

    init(
        transactionRepository: any TransactionRepository,
        fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.transactionRepository = transactionRepository
        self.fetchTaxCategoriesUseCase = fetchTaxCategoriesUseCase
        self.calendar = calendar
    }

    func execute(profile: TaxProfile) async throws -> TaxSummary {
        let relevantCategories = try await fetchTaxCategoriesUseCase.execute(country: profile.country)
        let dateRange = dateRange(for: profile)

        guard !relevantCategories.isEmpty else {
            return TaxSummary(
                financialYear: profile.financialYear,
                dateRange: dateRange,
                totalRelevantAmount: 0,
                transactionCount: 0,
                taxRelevantCategories: [],
                categoryBreakdown: []
            )
        }

        let filter = TransactionFilter(
            dateRange: dateRange,
            types: Set([.expense]),
            categoryIDs: Set(relevantCategories.map(\.id))
        )
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        var groupedAmounts: [UUID: (amount: Decimal, count: Int)] = [:]
        for transaction in transactions {
            guard let categoryID = transaction.categoryID else { continue }
            var entry = groupedAmounts[categoryID] ?? (amount: Decimal(0), count: 0)
            entry.amount += transaction.amount
            entry.count += 1
            groupedAmounts[categoryID] = entry
        }

        let breakdown = groupedAmounts
            .compactMap { categoryID, summary -> TaxSummaryCategory? in
                guard let category = relevantCategories.first(where: { $0.id == categoryID }) else {
                    return nil
                }
                return TaxSummaryCategory(
                    category: category,
                    totalAmount: summary.amount,
                    transactionCount: summary.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalAmount == rhs.totalAmount {
                    return lhs.category.name.localizedCaseInsensitiveCompare(rhs.category.name) == .orderedAscending
                }
                return lhs.totalAmount > rhs.totalAmount
            }

        let totalRelevantAmount = breakdown.reduce(Decimal(0)) { $0 + $1.totalAmount }
        let transactionCount = breakdown.reduce(0) { $0 + $1.transactionCount }

        return TaxSummary(
            financialYear: profile.financialYear,
            dateRange: dateRange,
            totalRelevantAmount: totalRelevantAmount,
            transactionCount: transactionCount,
            taxRelevantCategories: relevantCategories,
            categoryBreakdown: breakdown
        )
    }

    private func dateRange(for profile: TaxProfile) -> ClosedRange<Date> {
        switch profile.country {
        case .india:
            indiaFinancialYearRange(financialYear: profile.financialYear)
        case .unitedStates:
            usTaxYearRange(financialYear: profile.financialYear)
        }
    }

    private func indiaFinancialYearRange(financialYear: String) -> ClosedRange<Date> {
        let startYear = parsedLeadingYear(from: financialYear) ?? calendar.component(.year, from: .now)
        let start = calendar.date(from: DateComponents(year: startYear, month: 4, day: 1)) ?? .now
        let nextStart = calendar.date(from: DateComponents(year: startYear + 1, month: 4, day: 1)) ?? start
        return start...nextStart.addingTimeInterval(-1)
    }

    private func usTaxYearRange(financialYear: String) -> ClosedRange<Date> {
        let year = parsedLeadingYear(from: financialYear) ?? calendar.component(.year, from: .now)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .now
        let nextStart = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? start
        return start...nextStart.addingTimeInterval(-1)
    }

    private func parsedLeadingYear(from value: String) -> Int? {
        let prefix = value.prefix { $0.isNumber }
        return Int(prefix)
    }
}
