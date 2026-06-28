import Foundation

enum TransactionType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income, transfer, adjustment

    var displayName: String {
        switch self {
        case .expense: String(localized: "Expense")
        case .income: String(localized: "Income")
        case .transfer: String(localized: "Transfer")
        case .adjustment: String(localized: "Adjustment")
        }
    }
}

enum PaymentMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, creditCard, debitCard, bankTransfer, upi, wallet, other

    var displayName: String {
        switch self {
        case .cash: String(localized: "Cash")
        case .creditCard: String(localized: "Credit Card")
        case .debitCard: String(localized: "Debit Card")
        case .bankTransfer: String(localized: "Bank Transfer")
        case .upi: String(localized: "UPI")
        case .wallet: String(localized: "Wallet")
        case .other: String(localized: "Other")
        }
    }
}

/// Direction a `.transfer` leg moves money relative to its own `accountID`
/// (DATAINTEGRITY-1, A3). `.debit` = funds leave this account; `.credit` = funds
/// enter it. This makes a transfer leg's balance effect *derivable* from a single
/// row (paired with `transferPairID`), unlike the legacy two-symmetric-positive-
/// legs model. Optional: legacy legs have `nil` and are treated as not derivable.
enum TransferDirection: String, Sendable, Hashable, CaseIterable, Codable {
    case debit
    case credit
}

struct TransactionEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var amount: Decimal
    nonisolated var date: Date
    nonisolated var note: String?
    nonisolated var type: TransactionType
    nonisolated var paymentMethod: PaymentMethod
    nonisolated var currencyCode: String
    nonisolated var tags: [String]
    nonisolated var categoryID: UUID?
    nonisolated var accountID: UUID?
    nonisolated var payeeID: UUID?
    nonisolated var destinationAccountID: UUID?
    nonisolated var recurringRuleID: UUID?
    /// Shared identifier linking the two legs of a transfer so both can be
    /// reversed/edited together (DATAINTEGRITY-1). Nil for non-transfer rows.
    nonisolated var transferPairID: UUID?
    /// For `.transfer` legs, whether this leg debits or credits its `accountID`
    /// (DATAINTEGRITY-1, A3). Nil for non-transfer rows and legacy transfer legs.
    nonisolated var transferDirection: TransferDirection?
    nonisolated var documentIDs: [UUID]
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = .now,
        note: String? = nil,
        type: TransactionType = .expense,
        paymentMethod: PaymentMethod = .cash,
        currencyCode: String = CurrencyDefaults.code,
        tags: [String] = [],
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        payeeID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        recurringRuleID: UUID? = nil,
        transferPairID: UUID? = nil,
        transferDirection: TransferDirection? = nil,
        documentIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.type = type
        self.paymentMethod = paymentMethod
        self.currencyCode = currencyCode
        self.tags = tags
        self.categoryID = categoryID
        self.accountID = accountID
        self.payeeID = payeeID
        self.destinationAccountID = destinationAccountID
        self.recurringRuleID = recurringRuleID
        self.transferPairID = transferPairID
        self.transferDirection = transferDirection
        self.documentIDs = documentIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Equatable & Hashable (identity-based)

    nonisolated static func == (lhs: TransactionEntity, rhs: TransactionEntity) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension TransactionEntity {
    /// The single canonical signed effect this transaction applies to its own
    /// `accountID`, in account currency (DATAINTEGRITY-1/3/12, A3). This is the
    /// one place balance math lives; the ledger store, balance reconciliation,
    /// and transaction-edit reversal all use it instead of redefining their own.
    ///
    /// - `.expense`: `−amount`
    /// - `.income`, `.adjustment`: `+amount`
    /// - `.transfer`: direction-signed (`.debit` → `−amount`, `.credit` → `+amount`).
    ///   A legacy transfer leg with `transferDirection == nil` returns `0` and is
    ///   *not* balance-derivable — callers that need correctness over such legs
    ///   (e.g. reconciliation) must skip accounts that contain them.
    nonisolated var signedBalanceEffect: Decimal {
        switch type {
        case .expense:
            return -amount
        case .income, .adjustment:
            return amount
        case .transfer:
            switch transferDirection {
            case .debit: return -amount
            case .credit: return amount
            case nil: return 0
            }
        }
    }
}
