import Foundation

enum AccountType: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, bank, creditCard, loan, digitalWallet, investment, receivable, payable

    var displayName: String {
        switch self {
        case .cash: String(localized: "Cash")
        case .bank: String(localized: "Bank")
        case .creditCard: String(localized: "Credit Card")
        case .loan: String(localized: "Loan")
        case .digitalWallet: String(localized: "Digital Wallet")
        case .investment: String(localized: "Investment")
        case .receivable: String(localized: "Receivable")
        case .payable: String(localized: "Payable")
        }
    }

    nonisolated var isAsset: Bool {
        switch self {
        case .cash, .bank, .digitalWallet, .investment, .receivable: return true
        case .creditCard, .loan, .payable: return false
        }
    }
}

struct AccountEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var name: String
    nonisolated var type: AccountType
    nonisolated var balance: Decimal
    /// Balance before any transaction (DATAINTEGRITY-12). `nil` for legacy
    /// accounts created before Schema V3; reconciliation derives the implied
    /// opening on read for those rather than persisting a baseline.
    nonisolated var openingBalance: Decimal?
    nonisolated var currencyCode: String
    nonisolated var icon: String
    nonisolated var isArchived: Bool
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date
    /// Day of month the statement closes (1–31). Credit cards only (C4).
    nonisolated var statementDayOfMonth: Int?
    /// Day of month payment is due (1–31). Credit cards only (C4).
    nonisolated var dueDayOfMonth: Int?

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
