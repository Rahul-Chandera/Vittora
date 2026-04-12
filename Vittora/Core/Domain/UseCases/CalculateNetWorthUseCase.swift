import Foundation

struct NetWorthSummary: Sendable {
    let totalAssets: Decimal
    let totalLiabilities: Decimal

    var netWorth: Decimal {
        totalAssets - totalLiabilities
    }
}

struct CalculateNetWorthUseCase: Sendable {
    let accountRepository: any AccountRepository

    init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute() async throws -> NetWorthSummary {
        let accounts = try await accountRepository.fetchAll()
            .filter { !$0.isArchived }

        var totalAssets: Decimal = 0
        var totalLiabilities: Decimal = 0

        for account in accounts {
            if account.type.isAsset {
                totalAssets += account.balance
            } else {
                totalLiabilities += account.balance
            }
        }

        return NetWorthSummary(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities
        )
    }
}
