import Foundation
import VittoraCore

struct EmergencyFundReport: Sendable, Equatable {
    let snapshot: EmergencyFundSnapshot?
    let eligibleAccounts: [AccountEntity]
    let selectedAccountIDs: Set<UUID>
}

struct EmergencyFundUseCase: Sendable {
    private let recurringRuleRepository: any RecurringRuleRepository
    private let categoryRepository: any CategoryRepository
    private let transactionRepository: any TransactionRepository
    private let accountRepository: any AccountRepository
    private let savingsGoalRepository: any SavingsGoalRepository
    private let todayProvider: @Sendable () -> Date
    private let calendar: Calendar

    nonisolated init(
        recurringRuleRepository: any RecurringRuleRepository,
        categoryRepository: any CategoryRepository,
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        savingsGoalRepository: any SavingsGoalRepository,
        todayProvider: @escaping @Sendable () -> Date = { Date.now },
        calendar: Calendar = .current
    ) {
        self.recurringRuleRepository = recurringRuleRepository
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.savingsGoalRepository = savingsGoalRepository
        self.todayProvider = todayProvider
        self.calendar = calendar
    }

    func execute(
        selectedAccountIDs: Set<UUID>,
        currencyCode: String = CurrencyDefaults.code
    ) async throws -> EmergencyFundReport {
        let today = todayProvider()
        let categories = try await categoryRepository.fetchAll()
        let needsCategoryIDs = Set(
            categories
                .filter { $0.type == .expense && $0.spendingBucket == .needs }
                .map(\.id)
        )
        let rules = try await recurringRuleRepository.fetchActive()
        var baseline = EmergencyFundMath.recurringBaseline(
            rules: rules,
            needsCategoryIDs: needsCategoryIDs,
            today: today
        )

        if baseline == nil, !needsCategoryIDs.isEmpty {
            let history = try await fetchNeedsHistory(
                categoryIDs: needsCategoryIDs,
                through: today
            )
            baseline = EmergencyFundMath.historyBaseline(
                transactions: history,
                needsCategoryIDs: needsCategoryIDs,
                today: today,
                calendar: calendar
            )
        }

        // Scoped to the fund's currency, which also constrains the picker:
        // eligibleAccounts is what the view offers, so an account whose balance
        // could not be counted is never selectable in the first place.
        let accounts = try await accountRepository.fetchActive()
            .filter { $0.type.isAsset && $0.currencyCode == currencyCode }
        let goals = try await savingsGoalRepository.fetchAll()
        let validSelection = selectedAccountIDs.intersection(accounts.map(\.id))
        let currentFund = EmergencyFundMath.currentFund(
            accounts: accounts,
            selectedAccountIDs: validSelection,
            goals: goals,
            currencyCode: currencyCode
        )
        return EmergencyFundReport(
            snapshot: baseline.flatMap {
                EmergencyFundMath.snapshot(currentFund: currentFund, baseline: $0)
            },
            eligibleAccounts: accounts,
            selectedAccountIDs: validSelection
        )
    }

    private func fetchNeedsHistory(
        categoryIDs: Set<UUID>,
        through today: Date
    ) async throws -> [TransactionEntity] {
        let filter = TransactionFilter(
            dateRange: Date.distantPast...today,
            types: [.expense],
            categoryIDs: categoryIDs
        )
        let pageSize = 500
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
}

@MainActor
protocol EmergencyFundAccountSelectionStoring: AnyObject {
    var selectedAccountIDs: Set<UUID> { get set }
}

@MainActor
final class UserDefaultsEmergencyFundAccountSelectionStore: EmergencyFundAccountSelectionStoring {
    private let userDefaults: UserDefaults
    private let key = AppUserDefaults.StandardKey.emergencyFundAccountIDs

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var selectedAccountIDs: Set<UUID> {
        get {
            Set((userDefaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
        }
        set {
            userDefaults.set(newValue.map(\.uuidString).sorted(), forKey: key)
        }
    }
}
