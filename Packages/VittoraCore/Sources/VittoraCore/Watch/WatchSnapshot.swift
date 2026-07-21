import Foundation

/// Phone → watch snapshot delivered via `WCSession.updateApplicationContext`.
/// Amounts use `Decimal` Codable end-to-end (never `Double`).
public struct WatchSnapshot: Codable, Sendable, Equatable {
    public var todaySpend: Decimal
    public var budgetSpent: Decimal
    public var budgetTotal: Decimal
    public var recentTransactions: [WatchSnapshotTransaction]
    public var currencyCode: String
    public var generatedAt: Date

    public init(
        todaySpend: Decimal,
        budgetSpent: Decimal,
        budgetTotal: Decimal,
        recentTransactions: [WatchSnapshotTransaction],
        currencyCode: String,
        generatedAt: Date = .now
    ) {
        self.todaySpend = todaySpend
        self.budgetSpent = budgetSpent
        self.budgetTotal = budgetTotal
        self.recentTransactions = Array(recentTransactions.prefix(Self.maxRecentTransactions))
        self.currencyCode = currencyCode
        self.generatedAt = generatedAt
    }

    public static let maxRecentTransactions = 10

    public var budgetRemaining: Decimal { budgetTotal - budgetSpent }

    public func isStale(at date: Date, maximumAge: TimeInterval = 24 * 60 * 60) -> Bool {
        date.timeIntervalSince(generatedAt) > maximumAge
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
}

public struct WatchSnapshotTransaction: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var name: String
    public var amount: Decimal
    public var type: TransactionType

    public init(
        id: UUID = UUID(),
        date: Date,
        name: String,
        amount: Decimal,
        type: TransactionType
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.amount = amount
        self.type = type
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
