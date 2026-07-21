import Foundation

/// Phone → watch snapshot delivered via `WCSession.updateApplicationContext`.
/// Amounts use `Decimal` Codable end-to-end (never `Double`).
public struct WatchSnapshot: Codable, Sendable, Equatable {
    public var todaySpend: Decimal
    public var budgetSpent: Decimal
    public var budgetTotal: Decimal
    public var budgetPeriodKey: String
    public var recentTransactions: [WatchSnapshotTransaction]
    public var currencyCode: String
    public var generatedAt: Date

    public init(
        todaySpend: Decimal,
        budgetSpent: Decimal,
        budgetTotal: Decimal,
        budgetPeriodKey: String? = nil,
        recentTransactions: [WatchSnapshotTransaction],
        currencyCode: String,
        generatedAt: Date = .now
    ) {
        self.todaySpend = todaySpend
        self.budgetSpent = budgetSpent
        self.budgetTotal = budgetTotal
        self.budgetPeriodKey = budgetPeriodKey ?? Self.monthlyPeriodKey(for: generatedAt)
        self.recentTransactions = Array(recentTransactions.prefix(Self.maxRecentTransactions))
        self.currencyCode = currencyCode
        self.generatedAt = generatedAt
    }

    public static let maxRecentTransactions = 10

    public var budgetRemaining: Decimal { budgetTotal - budgetSpent }

    public static func monthlyPeriodKey(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    /// Encodes for `WCSession` application-context / disk cache (JSON `Data`).
    public func encodeForTransport() throws -> Data {
        try Self.makeEncoder().encode(self)
    }

    public static func decodeFromTransport(_ data: Data) throws -> WatchSnapshot {
        try makeDecoder().decode(WatchSnapshot.self, from: data)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private enum CodingKeys: String, CodingKey {
        case todaySpend
        case budgetSpent
        case budgetTotal
        case budgetPeriodKey
        case recentTransactions
        case currencyCode
        case generatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.init(
            todaySpend: try container.decode(Decimal.self, forKey: .todaySpend),
            budgetSpent: try container.decode(Decimal.self, forKey: .budgetSpent),
            budgetTotal: try container.decode(Decimal.self, forKey: .budgetTotal),
            budgetPeriodKey: try container.decodeIfPresent(String.self, forKey: .budgetPeriodKey),
            recentTransactions: try container.decode([WatchSnapshotTransaction].self, forKey: .recentTransactions),
            currencyCode: try container.decode(String.self, forKey: .currencyCode),
            generatedAt: generatedAt
        )
    }
}

public struct WatchSnapshotTransaction: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var name: String
    public var categoryIcon: String
    public var amount: Decimal
    public var type: TransactionType

    public init(
        id: UUID = UUID(),
        date: Date,
        name: String,
        categoryIcon: String? = nil,
        amount: Decimal,
        type: TransactionType
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.categoryIcon = categoryIcon ?? Self.fallbackIcon(for: type)
        self.amount = amount
        self.type = type
    }

    private static func fallbackIcon(for type: TransactionType) -> String {
        switch type {
        case .expense: "arrow.down.circle.fill"
        case .income: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        case .adjustment: "plusminus.circle.fill"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case name
        case categoryIcon
        case amount
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TransactionType.self, forKey: .type)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            date: try container.decode(Date.self, forKey: .date),
            name: try container.decode(String.self, forKey: .name),
            categoryIcon: try container.decodeIfPresent(String.self, forKey: .categoryIcon),
            amount: try container.decode(Decimal.self, forKey: .amount),
            type: type
        )
    }
}

/// Keys shared by phone and watch for WatchConnectivity payloads.
public enum WatchConnectivityPayloadKey {
    public static let snapshotData = "snapshotData"
    public static let payloadType = "type"
    public static let queuedExpense = "queuedExpense"
    public static let amount = "amount"
    public static let categoryID = "categoryID"
    public static let createdAt = "createdAt"
}

/// Watch → phone queued expense delivered via `WCSession.transferUserInfo`.
/// Phone validates and commits through `AddTransactionUseCase`.
public struct QueuedWatchExpense: Codable, Sendable, Equatable {
    public var amount: Decimal
    public var categoryID: UUID?
    public var createdAt: Date

    public init(amount: Decimal, categoryID: UUID? = nil, createdAt: Date = .now) {
        self.amount = amount
        self.categoryID = categoryID
        self.createdAt = createdAt
    }

    public func encodeForTransport() throws -> Data {
        try WatchSnapshot.makeEncoder().encode(self)
    }

    public static func decodeFromTransport(_ data: Data) throws -> QueuedWatchExpense {
        try WatchSnapshot.makeDecoder().decode(QueuedWatchExpense.self, from: data)
    }

    /// Builds a `transferUserInfo` dictionary. Amount is a decimal string so plist
    /// transport never widens money through `Double`.
    public func userInfoDictionary() -> [String: Any] {
        var info: [String: Any] = [
            WatchConnectivityPayloadKey.payloadType: WatchConnectivityPayloadKey.queuedExpense,
            WatchConnectivityPayloadKey.amount: "\(amount)",
            WatchConnectivityPayloadKey.createdAt: createdAt.timeIntervalSince1970,
        ]
        if let categoryID {
            info[WatchConnectivityPayloadKey.categoryID] = categoryID.uuidString
        }
        return info
    }

    public static func fromUserInfo(_ userInfo: [String: Any]) throws -> QueuedWatchExpense {
        guard let type = userInfo[WatchConnectivityPayloadKey.payloadType] as? String,
              type == WatchConnectivityPayloadKey.queuedExpense else {
            throw VittoraError.validationFailed(
                String(localized: "Unknown watch payload type.")
            )
        }

        guard let amountRaw = userInfo[WatchConnectivityPayloadKey.amount] as? String,
              let amount = Decimal(string: amountRaw),
              amount > 0 else {
            throw VittoraError.validationFailed(
                String(localized: "Watch expense amount is invalid.")
            )
        }

        var categoryID: UUID?
        if let categoryRaw = userInfo[WatchConnectivityPayloadKey.categoryID] as? String {
            guard let parsed = UUID(uuidString: categoryRaw) else {
                throw VittoraError.validationFailed(
                    String(localized: "Watch expense category is invalid.")
                )
            }
            categoryID = parsed
        }

        let createdAt: Date
        if let interval = userInfo[WatchConnectivityPayloadKey.createdAt] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: interval)
        } else if let number = userInfo[WatchConnectivityPayloadKey.createdAt] as? NSNumber {
            createdAt = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            createdAt = .now
        }

        return QueuedWatchExpense(amount: amount, categoryID: categoryID, createdAt: createdAt)
    }
}
