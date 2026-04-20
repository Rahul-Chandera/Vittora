import Foundation

struct FetchAccountsUseCase: Sendable {
    let accountRepository: any AccountRepository

    init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute() async throws -> [AccountEntity] {
        let accounts = try await accountRepository.fetchActive()
        return accounts
            .sorted { a, b in
                if a.type == b.type {
                    return a.name < b.name
                }
                // Assets come before liabilities
                if a.type.isAsset && !b.type.isAsset {
                    return true
                }
                if !a.type.isAsset && b.type.isAsset {
                    return false
                }
                return a.name < b.name
            }
    }

    func executeGroupedByType() async throws -> [AccountType: [AccountEntity]] {
        let accounts = try await execute()
        var grouped: [AccountType: [AccountEntity]] = [:]
        for account in accounts {
            if grouped[account.type] == nil {
                grouped[account.type] = []
            }
            grouped[account.type]?.append(account)
        }
        return grouped
    }
}
