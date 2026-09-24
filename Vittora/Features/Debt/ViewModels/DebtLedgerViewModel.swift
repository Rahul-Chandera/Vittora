import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class DebtLedgerViewModel {
    var ledgerEntries: [DebtLedgerEntry] = []
    var balance: DebtBalance?
    var overdueEntries: [DebtEntry] = []
    var isLoading = false
    var error: String?

    // Split on the NET position, not the gross totals.
    //
    // Filtering on `totalLent > 0` and `totalBorrowed > 0` put anyone with debt
    // in both directions into BOTH sections, while DebtRowView shows
    // `abs(netBalance)` — so one payee owing you 150 and owed 300 appeared
    // twice, each row reading 150, and the "Owed to You" copy rendered in the
    // you-owe colour because the net is negative. Three contradictions from one
    // mismatch: the row was net, the sections were gross.
    //
    // Someone square with you (150 each way) now appears in neither section
    // rather than both, which is what "settled" should look like. The gross
    // totals are still on the summary card above, beside the net.
    var owedToMeEntries: [DebtLedgerEntry] {
        ledgerEntries.filter { $0.netBalance > 0 }
    }
    var iOweEntries: [DebtLedgerEntry] {
        ledgerEntries.filter { $0.netBalance < 0 }
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
