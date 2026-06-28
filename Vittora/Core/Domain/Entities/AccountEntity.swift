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
    /// Balance before any transaction (DATAINTEGRITY-12). `nil` for legacy
    /// accounts created before Schema V3; reconciliation derives the implied
    /// opening on read for those rather than persisting a baseline.
    var openingBalance: Decimal?
    var currencyCode: String
    var icon: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    /// Day of month the statement closes (1–31). Credit cards only (C4).
    var statementDayOfMonth: Int?
    /// Day of month payment is due (1–31). Credit cards only (C4).
    var dueDayOfMonth: Int?

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        openingBalance: Decimal? = nil,
        currencyCode: String = CurrencyDefaults.code,
        icon: String = "building.columns.fill",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        statementDayOfMonth: Int? = nil,
        dueDayOfMonth: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.openingBalance = openingBalance
        self.currencyCode = currencyCode
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.statementDayOfMonth = statementDayOfMonth
        self.dueDayOfMonth = dueDayOfMonth
    }

    // MARK: - Equatable & Hashable (identity-based)

    static func == (lhs: AccountEntity, rhs: AccountEntity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
