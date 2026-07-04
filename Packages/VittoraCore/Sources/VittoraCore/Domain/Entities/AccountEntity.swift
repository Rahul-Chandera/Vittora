import Foundation

public enum AccountType: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, bank, creditCard, loan, digitalWallet, investment, receivable, payable

    public var displayName: String {
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

    public nonisolated var isAsset: Bool {
        switch self {
        case .cash, .bank, .digitalWallet, .investment, .receivable: return true
        case .creditCard, .loan, .payable: return false
        }
    }
}

public struct AccountEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var type: AccountType
    public nonisolated var balance: Decimal
    /// Balance before any transaction (DATAINTEGRITY-12). `nil` for legacy
    /// accounts created before Schema V3; reconciliation derives the implied
    /// opening on read for those rather than persisting a baseline.
    public nonisolated var openingBalance: Decimal?
    public nonisolated var currencyCode: String
    public nonisolated var icon: String
    public nonisolated var isArchived: Bool
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date
    /// Day of month the statement closes (1–31). Credit cards only (C4).
    public nonisolated var statementDayOfMonth: Int?
    /// Day of month payment is due (1–31). Credit cards only (C4).
    public nonisolated var dueDayOfMonth: Int?

    public nonisolated init(
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

    public static func == (lhs: AccountEntity, rhs: AccountEntity) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
