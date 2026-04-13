import Foundation

@Observable
@MainActor
final class SplitGroupDetailViewModel {
    private let splitGroupRepository: any SplitGroupRepository
    private let payeeRepository: any PayeeRepository
    private let settleUseCase: SettleGroupExpenseUseCase

    var group: SplitGroup
    var expenses: [GroupExpense] = []
    var memberNames: [UUID: String] = [:]
    var simplifiedBalances: [MemberBalance] = []
    var isLoading = false
    var error: String?

    var outstandingExpenses: [GroupExpense] { expenses.filter { !$0.isSettled } }
    var settledExpenses: [GroupExpense] { expenses.filter { $0.isSettled } }

    init(
        group: SplitGroup,
        splitGroupRepository: any SplitGroupRepository,
        payeeRepository: any PayeeRepository
    ) {
        self.group = group
        self.splitGroupRepository = splitGroupRepository
        self.payeeRepository = payeeRepository
        self.settleUseCase = SettleGroupExpenseUseCase(splitGroupRepository: splitGroupRepository)
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let fetchedExpenses = splitGroupRepository.fetchExpenses(forGroup: group.id)
            async let allPayees = payeeRepository.fetchAll()

            let (exp, payees) = try await (fetchedExpenses, allPayees)
            let payeeMap = Dictionary(uniqueKeysWithValues: payees.map { ($0.id, $0.name) })

            expenses = exp
            memberNames = group.memberIDs.reduce(into: [:]) { dict, id in
                dict[id] = payeeMap[id] ?? String(localized: "Unknown")
            }
            simplifiedBalances = SimplifyDebtsUseCase.simplify(
                expenses: outstandingExpenses,
                memberIDs: group.memberIDs
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func settleExpense(_ expense: GroupExpense) async {
        do {
            try await settleUseCase.settleExpense(expense)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func settleAll() async {
        do {
            try await settleUseCase.settleAll(in: group)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteExpense(_ id: UUID) async {
        do {
            try await splitGroupRepository.deleteExpense(id)
            expenses.removeAll { $0.id == id }
            simplifiedBalances = SimplifyDebtsUseCase.simplify(
                expenses: outstandingExpenses,
                memberIDs: group.memberIDs
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func memberName(for id: UUID) -> String {
        memberNames[id] ?? String(localized: "Unknown")
    }
}
