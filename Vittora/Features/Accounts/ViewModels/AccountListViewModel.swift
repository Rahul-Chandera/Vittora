import Foundation
import Observation

@Observable
@MainActor
final class AccountListViewModel {
    var accounts: [AccountEntity] = []
    var groupedAccounts: [AccountType: [AccountEntity]] = [:]
    var netWorth: Decimal = 0
    var totalAssets: Decimal = 0
    var totalLiabilities: Decimal = 0
    var isLoading = false
    var error: String?

    private let fetchAccountsUseCase: FetchAccountsUseCase
    private let calculateNetWorthUseCase: CalculateNetWorthUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase

    init(
        fetchAccountsUseCase: FetchAccountsUseCase,
        calculateNetWorthUseCase: CalculateNetWorthUseCase,
        deleteAccountUseCase: DeleteAccountUseCase
    ) {
        self.fetchAccountsUseCase = fetchAccountsUseCase
        self.calculateNetWorthUseCase = calculateNetWorthUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
    }

    func loadAccounts() async {
        isLoading = true
        error = nil

        do {
            async let accountsResult = fetchAccountsUseCase.executeGroupedByType()
            async let netWorthResult = calculateNetWorthUseCase.execute()

            let (grouped, summary) = try await (accountsResult, netWorthResult)

            // Flatten grouped accounts for display
            var allAccounts: [AccountEntity] = []
            for type in AccountType.allCases {
                if let accountsForType = grouped[type] {
                    allAccounts.append(contentsOf: accountsForType)
                }
            }

            self.accounts = allAccounts
            self.groupedAccounts = grouped
            self.totalAssets = summary.totalAssets
            self.totalLiabilities = summary.totalLiabilities
            self.netWorth = summary.netWorth
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteAccount(id: UUID) async {
        error = nil

        do {
            try await deleteAccountUseCase.delete(id: id)
            // Reload accounts after deletion
            await loadAccounts()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func archiveAccount(id: UUID) async {
        error = nil

        do {
            try await deleteAccountUseCase.archive(id: id)
            // Reload accounts after archiving
            await loadAccounts()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
