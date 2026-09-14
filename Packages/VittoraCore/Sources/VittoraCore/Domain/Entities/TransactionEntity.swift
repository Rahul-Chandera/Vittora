import Foundation

public enum TransactionType: String, Sendable, Hashable, CaseIterable, Codable {
    case expense, income, transfer, adjustment

    public var displayName: String {
        switch self {
        case .expense: String(localized: "Expense")
        case .income: String(localized: "Income")
        case .transfer: String(localized: "Transfer")
        case .adjustment: String(localized: "Adjustment")
        }
    }
}

public enum PaymentMethod: String, Sendable, Hashable, CaseIterable, Codable {
    case cash, creditCard, debitCard, bankTransfer, upi, wallet, other

    public var displayName: String {
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
public enum TransferDirection: String, Sendable, Hashable, CaseIterable, Codable {
    case debit
    case credit
}

/// What the smart categorizer proposed when a transaction was first created
/// (Schema V8, M3.2 instrumentation). Recorded so 1.8.0 can train an on-device
/// classifier on accept-vs-override without inventing a separate event log.
///
/// Deliberately three-state via `Optional`:
/// - `nil`               — not instrumented: the row predates V8, so nothing is known.
/// - `.noSuggestion`     — the categorizer ran and proposed nothing.
/// - `.suggested(id)`    — the categorizer proposed `id`.
///
/// "Accepted" is then `.suggested(id)` where `id == categoryID`; "overridden" is the
/// pair of ids. No new entity and no duplicated columns — payee, note, merchant text,
/// amount and the chosen category already live on the transaction.
public enum CategorySuggestion: Sendable, Hashable {
    case noSuggestion
    case suggested(UUID)
}

public struct TransactionEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var amount: Decimal
    public nonisolated var date: Date
    public nonisolated var note: String?
    public nonisolated var type: TransactionType
    public nonisolated var paymentMethod: PaymentMethod
    public nonisolated var currencyCode: String
    public nonisolated var tags: [String]
    public nonisolated var categoryID: UUID?
    public nonisolated var accountID: UUID?
    public nonisolated var payeeID: UUID?
    public nonisolated var destinationAccountID: UUID?
    public nonisolated var recurringRuleID: UUID?
    /// Shared identifier linking the two legs of a transfer so both can be
    /// reversed/edited together (DATAINTEGRITY-1). Nil for non-transfer rows.
    public nonisolated var transferPairID: UUID?
    /// For `.transfer` legs, whether this leg debits or credits its `accountID`
    /// (DATAINTEGRITY-1, A3). Nil for non-transfer rows and legacy transfer legs.
    public nonisolated var transferDirection: TransferDirection?
    /// What the categorizer proposed at creation time (Schema V8). Nil on rows
    /// created before V8. Never rewritten by an edit — see `TransactionMapper`.
    public nonisolated var categorySuggestion: CategorySuggestion?
    public nonisolated var documentIDs: [UUID]
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
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
        categorySuggestion: CategorySuggestion? = nil,
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
        self.categorySuggestion = categorySuggestion
        self.documentIDs = documentIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Equatable & Hashable (identity-based)

    // Value equality, not identity. An id-only `==` makes SwiftUI treat a
    // record whose fields changed as unchanged, so any row whose only input is
    // this entity never re-renders — it keeps the old figures until the app is
    // relaunched. That shipped as a budget bug; see BudgetEntity for the full
    // account. `createdAt`/`updatedAt` are audit metadata, not displayed
    // content, so they stay out of the comparison. `categorySuggestion` is the
    // same: instrumentation metadata never rendered, so including it would make
    // SwiftUI diff rows on a field it never shows. Dedup by identity should
    // key on `id` explicitly rather than lean on `==`.
    public nonisolated static func == (lhs: TransactionEntity, rhs: TransactionEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.amount == rhs.amount
            && lhs.date == rhs.date
            && lhs.note == rhs.note
            && lhs.type == rhs.type
            && lhs.paymentMethod == rhs.paymentMethod
            && lhs.currencyCode == rhs.currencyCode
            && lhs.tags == rhs.tags
            && lhs.categoryID == rhs.categoryID
            && lhs.accountID == rhs.accountID
            && lhs.payeeID == rhs.payeeID
            && lhs.destinationAccountID == rhs.destinationAccountID
            && lhs.recurringRuleID == rhs.recurringRuleID
            && lhs.transferPairID == rhs.transferPairID
            && lhs.transferDirection == rhs.transferDirection
            && lhs.documentIDs == rhs.documentIDs
    }
    // Hash stays id-only: legal (equal values share a hash) and keeps
    // Set/Dictionary bucketing stable as mutable fields change.
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
    public nonisolated var signedBalanceEffect: Decimal {
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

extension CategorySuggestion {
    /// Sentinel-encoded so a single optional column carries all three states.
    /// A UUID string is never empty, so `""` is unambiguous.
    var rawValue: String {
        switch self {
        case .noSuggestion: ""
        case .suggested(let id): id.uuidString
        }
    }

    /// Decodes defensively: a non-empty value that is not a UUID is treated as
    /// unknown (`nil`) rather than as `.noSuggestion`, so a value written by a
    /// future version cannot silently mislabel training data.
    init?(rawValue: String?) {
        guard let rawValue else { return nil }
        if rawValue.isEmpty {
            self = .noSuggestion
        } else if let id = UUID(uuidString: rawValue) {
            self = .suggested(id)
        } else {
            return nil
        }
    }
}
