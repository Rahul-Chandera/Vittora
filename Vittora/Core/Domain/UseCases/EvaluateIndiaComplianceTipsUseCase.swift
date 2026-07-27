import Foundation
import VittoraCore

struct EvaluateIndiaComplianceTipsUseCase: Sendable {
    private let transactionRepository: any TransactionRepository
    private let accountRepository: any AccountRepository
    private let categoryRepository: any CategoryRepository
    private let dismissalStore: any IndiaComplianceTipDismissalStoring
    private let calendar: Calendar
    private let pageSize: Int

    nonisolated init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        dismissalStore: any IndiaComplianceTipDismissalStoring = UserDefaultsIndiaComplianceTipDismissalStore(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        pageSize: Int = 500
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.dismissalStore = dismissalStore
        self.calendar = calendar
        self.pageSize = pageSize
    }

    func execute(profile: TaxProfile) async throws -> [IndiaComplianceTip] {
        guard profile.country == .india else { return [] }

        let dateRange = indiaFinancialYearRange(financialYear: profile.financialYear)
        let transactions = try await fetchAllTransactions(dateRange: dateRange)
        let accounts = try await accountRepository.fetchAll()
        let categories = try await categoryRepository.fetchAll()

        let tips = IndiaComplianceTipEngine.evaluate(
            IndiaComplianceTipEngine.Input(
                country: profile.country,
                financialYear: profile.financialYear,
                incomeSourceType: profile.incomeSourceType,
                annualIncome: profile.annualIncome,
                transactions: transactions,
                accountsByID: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) }),
                categoriesByID: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }),
                calendar: calendar
            )
        )

        return tips.filter {
            !dismissalStore.isDismissed(ruleID: $0.ruleID, financialYear: profile.financialYear)
        }
    }

    func dismiss(tip: IndiaComplianceTip, financialYear: String) {
        dismissalStore.dismiss(ruleID: tip.ruleID, financialYear: financialYear)
    }

    private func fetchAllTransactions(dateRange: ClosedRange<Date>) async throws -> [TransactionEntity] {
        let filter = TransactionFilter(dateRange: dateRange)
        var offset = 0
        var transactions: [TransactionEntity] = []
        while true {
            let page = try await transactionRepository.fetchPage(
                filter: filter,
                offset: offset,
                limit: pageSize
            )
            transactions.append(contentsOf: page)
            guard page.count == pageSize else { return transactions }
            offset += page.count
        }
    }

    private func indiaFinancialYearRange(financialYear: String) -> ClosedRange<Date> {
        let startYear = parsedLeadingYear(from: financialYear) ?? calendar.component(.year, from: .now)
        let start = calendar.date(from: DateComponents(year: startYear, month: 4, day: 1)) ?? .now
        let nextStart = calendar.date(from: DateComponents(year: startYear + 1, month: 4, day: 1)) ?? start
        return start...nextStart.addingTimeInterval(-1)
    }

    private func parsedLeadingYear(from value: String) -> Int? {
        let prefix = value.prefix { $0.isNumber }
        return Int(prefix)
    }
}
