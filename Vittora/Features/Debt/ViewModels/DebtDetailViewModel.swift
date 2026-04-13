import Foundation
import Observation

@Observable
@MainActor
final class DebtDetailViewModel {
    var entries: [DebtEntry] = []
    var payee: PayeeEntity?
    var isLoading = false
    var error: String?
    var showSettlementForm = false
    var selectedDebtID: UUID?

    var totalLent: Decimal {
        entries.filter { $0.direction == .lent && !$0.isSettled }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }
    var totalBorrowed: Decimal {
        entries.filter { $0.direction == .borrowed && !$0.isSettled }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }
    var netBalance: Decimal { totalLent - totalBorrowed }

    private let debtRepository: any DebtRepository
    private let payeeRepository: any PayeeRepository
    private let settleUseCase: SettleDebtUseCase
    let payeeID: UUID

    init(
        payeeID: UUID,
        debtRepository: any DebtRepository,
        payeeRepository: any PayeeRepository,
        settleUseCase: SettleDebtUseCase
    ) {
        self.payeeID = payeeID
        self.debtRepository = debtRepository
        self.payeeRepository = payeeRepository
        self.settleUseCase = settleUseCase
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let entriesTask = debtRepository.fetchForPayee(payeeID)
            async let payeeTask   = payeeRepository.fetchByID(payeeID)
            let (fetched, fetchedPayee) = try await (entriesTask, payeeTask)
            entries = fetched.sorted { $0.createdAt > $1.createdAt }
            payee   = fetchedPayee
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func settle(debtID: UUID, amount: Decimal, accountID: UUID?) async {
        error = nil
        do {
            try await settleUseCase.execute(
                debtID: debtID,
                settlementAmount: amount,
                accountID: accountID
            )
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
