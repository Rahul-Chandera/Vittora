import Foundation
import Testing
@testable import Vittora

@Suite("ReportsHomeViewModel Tests")
@MainActor
struct ReportsHomeViewModelTests {

    private func makeViewModel(txRepo: MockTransactionRepository = MockTransactionRepository()) -> ReportsHomeViewModel {
        ReportsHomeViewModel(transactionRepository: txRepo)
    }

    // MARK: - Initial state

    @Test("starts with zero amounts and no error")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.monthSpending == 0)
        #expect(vm.monthIncome == 0)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - load()

    @Test("load() clears isLoading after completion")
    func loadClearsIsLoading() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.isLoading == false)
    }

    @Test("load() with no transactions leaves amounts at zero")
    func loadNoTransactions() async {
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.monthSpending == 0)
        #expect(vm.monthIncome == 0)
        #expect(vm.error == nil)
    }

    @Test("load() sums current-month expense transactions into monthSpending")
    func loadSumsExpenses() async {
        let txRepo = MockTransactionRepository()
        let now = Date()
        await txRepo.seed(TransactionEntity(amount: 100, date: now, type: .expense))
        await txRepo.seed(TransactionEntity(amount: 50, date: now, type: .expense))
        await txRepo.seed(TransactionEntity(amount: 200, date: now, type: .income))

        let vm = makeViewModel(txRepo: txRepo)
        await vm.load()

        #expect(vm.monthSpending == 150)
        #expect(vm.monthIncome == 200)
    }

    @Test("load() sets error on repository failure")
    func loadSetsErrorOnFailure() async {
        let txRepo = MockTransactionRepository()
        await txRepo.setShouldThrow(true)

        let vm = makeViewModel(txRepo: txRepo)
        await vm.load()

        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - formattedAmount

    @Test("formattedAmount formats positive decimal as currency string")
    func formattedAmountPositive() {
        let vm = makeViewModel()
        let result = vm.formattedAmount(Decimal(100))
        #expect(result.contains("100"))
    }

    @Test("formattedAmount handles zero")
    func formattedAmountZero() {
        let vm = makeViewModel()
        let result = vm.formattedAmount(0)
        #expect(result.contains("0"))
    }
}

extension MockTransactionRepository {
    func setShouldThrow(_ value: Bool) async {
        shouldThrowError = value
    }
}
