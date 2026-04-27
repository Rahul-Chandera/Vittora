import Foundation
import Testing
@testable import Vittora

@Suite("DashboardViewModel Tests")
@MainActor
struct DashboardViewModelTests {

    private func makeViewModel(
        txRepo: MockTransactionRepository,
        accountRepo: MockAccountRepository
    ) -> DashboardViewModel {
        let categoryRepo = MockCategoryRepository()
        let budgetRepo = MockBudgetRepository()
        let recurringRepo = MockRecurringRuleRepository()
        return DashboardViewModel(
            dashboardDataUseCase: DashboardDataUseCase(
                transactionRepository: txRepo,
                accountRepository: accountRepo,
                categoryRepository: categoryRepo,
                budgetRepository: budgetRepo,
                recurringRuleRepository: recurringRepo
            ),
            monthComparisonUseCase: MonthComparisonUseCase(transactionRepository: txRepo)
        )
    }

    private func makeViewModel() -> DashboardViewModel {
        makeViewModel(
            txRepo: MockTransactionRepository(),
            accountRepo: MockAccountRepository()
        )
    }

    // MARK: - Initial state

    @Test("starts with nil dashboardData and no error")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.dashboardData == nil)
        #expect(vm.comparison == nil)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - load()

    @Test("load() populates dashboardData on success")
    func loadPopulatesDashboardData() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.dashboardData != nil)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("load() populates comparison on success")
    func loadPopulatesComparison() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.comparison != nil)
    }

    @Test("load() clears isLoading after completion")
    func loadClearsIsLoading() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.isLoading == false)
    }

    @Test("load() computes zero net worth when no accounts")
    func loadZeroNetWorthNoAccounts() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.dashboardData?.netWorth == 0)
    }

    @Test("load() computes net worth from active accounts")
    func loadComputesNetWorth() async {
        let accountRepo = MockAccountRepository()
        let asset = AccountEntity(name: "Savings", type: .bank, balance: 5000)
        let liability = AccountEntity(name: "Credit", type: .creditCard, balance: 1000)
        try? await accountRepo.create(asset)
        try? await accountRepo.create(liability)

        let vm = makeViewModel(txRepo: MockTransactionRepository(), accountRepo: accountRepo)
        await vm.load()

        // net worth = assets (5000) - liabilities (1000) = 4000
        #expect(vm.dashboardData?.netWorth == 4000)
    }

    @Test("load() excludes archived accounts from net worth")
    func loadExcludesArchivedAccounts() async {
        let accountRepo = MockAccountRepository()
        let active = AccountEntity(name: "Active", type: .bank, balance: 3000)
        let archived = AccountEntity(name: "Archived", type: .bank, balance: 99999, isArchived: true)
        try? await accountRepo.create(active)
        try? await accountRepo.create(archived)

        let vm = makeViewModel(txRepo: MockTransactionRepository(), accountRepo: accountRepo)
        await vm.load()

        #expect(vm.dashboardData?.netWorth == 3000)
        #expect(vm.dashboardData?.accountSummary.count == 1)
    }

    @Test("load() computes month spending from expense transactions")
    func loadComputesMonthSpending() async {
        let txRepo = MockTransactionRepository()
        let now = Date()
        await txRepo.seed(TransactionEntity(amount: 100, date: now, type: .expense))
        await txRepo.seed(TransactionEntity(amount: 200, date: now, type: .expense))
        await txRepo.seed(TransactionEntity(amount: 500, date: now, type: .income))

        let vm = makeViewModel(txRepo: txRepo, accountRepo: MockAccountRepository())
        await vm.load()

        #expect(vm.dashboardData?.monthSpending == 300)
        #expect(vm.dashboardData?.monthIncome == 500)
    }

    @Test("load() sets error on repository failure")
    func loadSetsErrorOnFailure() async {
        let accountRepo = MockAccountRepository()
        accountRepo.shouldThrowError = true

        let vm = makeViewModel(txRepo: MockTransactionRepository(), accountRepo: accountRepo)
        await vm.load()

        #expect(vm.error != nil)
        #expect(vm.dashboardData == nil)
        #expect(vm.isLoading == false)
    }

    @Test("refresh() reloads data")
    func refreshReloadsData() async {
        let vm = makeViewModel()
        await vm.refresh()
        #expect(vm.dashboardData != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - Formatted helpers

    @Test("formattedAmount formats decimal as currency")
    func formattedAmountFormatsCurrency() {
        let vm = makeViewModel()
        let formatted = vm.formattedAmount(Decimal(1234))
        #expect(formatted.contains("1,234") || formatted.contains("1234"))
    }

    @Test("formattedAmount handles zero")
    func formattedAmountHandlesZero() {
        let vm = makeViewModel()
        let formatted = vm.formattedAmount(0)
        #expect(formatted.contains("0"))
    }

    @Test("formattedPercent formats with one decimal place")
    func formattedPercentOneDecimal() {
        let vm = makeViewModel()
        #expect(vm.formattedPercent(12.5) == "12.5%")
    }

    @Test("formattedPercent uses absolute value")
    func formattedPercentAbsoluteValue() {
        let vm = makeViewModel()
        #expect(vm.formattedPercent(-8.3) == "8.3%")
    }
}
