import Foundation

enum AccountType: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, bank, creditCard, loan, digitalWallet, investment, receivable, payable

    var isAsset: Bool {
        switch self {
        case .cash, .bank, .digitalWallet, .investment, .receivable: return true
        case .creditCard, .loan, .payable: return false
        }
    }
}

struct AccountEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var name: String
    var type: AccountType
    var balance: Decimal
    var currencyCode: String
    var icon: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        currencyCode: String = "USD",
        icon: String = "building.columns.fill",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.currencyCode = currencyCode
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
