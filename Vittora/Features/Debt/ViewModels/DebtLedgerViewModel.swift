import Foundation
import Observation

@Observable
@MainActor
final class DebtLedgerViewModel {
    var ledgerEntries: [DebtLedgerEntry] = []
    var balance: DebtBalance?
    var overdueEntries: [DebtEntry] = []
    var isLoading = false
    var error: String?

    var owedToMeEntries: [DebtLedgerEntry] {
        ledgerEntries.filter { $0.totalLent > 0 }
    }
    var iOweEntries: [DebtLedgerEntry] {
        ledgerEntries.filter { $0.totalBorrowed > 0 }
    }

    private let fetchLedgerUseCase: FetchDebtLedgerUseCase
    private let calculateBalanceUseCase: CalculateDebtBalanceUseCase
    private let fetchOverdueUseCase: FetchOverdueDebtsUseCase

    init(
        fetchLedgerUseCase: FetchDebtLedgerUseCase,
        calculateBalanceUseCase: CalculateDebtBalanceUseCase,
        fetchOverdueUseCase: FetchOverdueDebtsUseCase
    ) {
        self.fetchLedgerUseCase = fetchLedgerUseCase
        self.calculateBalanceUseCase = calculateBalanceUseCase
        self.fetchOverdueUseCase = fetchOverdueUseCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let ledgerTask   = fetchLedgerUseCase.execute()
            async let balanceTask  = calculateBalanceUseCase.execute()
            async let overdueTask  = fetchOverdueUseCase.execute()
            let (ledger, bal, overdue) = try await (ledgerTask, balanceTask, overdueTask)
            ledgerEntries  = ledger
            balance        = bal
            overdueEntries = overdue
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
