import Foundation

enum RecurrenceFrequency: Sendable, Hashable, Codable {
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
    case custom(days: Int)

    enum CodingKeys: String, CodingKey {
        case daily, weekly, biweekly, monthly, quarterly, yearly, custom
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.daily) {
            self = .daily
        } else if container.contains(.weekly) {
            self = .weekly
        } else if container.contains(.biweekly) {
            self = .biweekly
        } else if container.contains(.monthly) {
            self = .monthly
        } else if container.contains(.quarterly) {
            self = .quarterly
        } else if container.contains(.yearly) {
            self = .yearly
        } else if container.contains(.custom) {
            let days = try container.decode(Int.self, forKey: .custom)
            self = .custom(days: days)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid RecurrenceFrequency"
            ))
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(true, forKey: .daily)
        case .weekly:
            try container.encode(true, forKey: .weekly)
        case .biweekly:
            try container.encode(true, forKey: .biweekly)
        case .monthly:
            try container.encode(true, forKey: .monthly)
        case .quarterly:
            try container.encode(true, forKey: .quarterly)
        case .yearly:
            try container.encode(true, forKey: .yearly)
        case .custom(let days):
            try container.encode(days, forKey: .custom)
        }
    }
}

extension RecurrenceFrequency {
    nonisolated static func == (lhs: RecurrenceFrequency, rhs: RecurrenceFrequency) -> Bool {
        switch (lhs, rhs) {
        case (.daily, .daily), (.weekly, .weekly), (.biweekly, .biweekly),
             (.monthly, .monthly), (.quarterly, .quarterly), (.yearly, .yearly):
            return true
        case (.custom(let left), .custom(let right)):
            return left == right
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .daily: hasher.combine(0)
        case .weekly: hasher.combine(1)
        case .biweekly: hasher.combine(2)
        case .monthly: hasher.combine(3)
        case .quarterly: hasher.combine(4)
        case .yearly: hasher.combine(5)
        case .custom(let days):
            hasher.combine(6)
            hasher.combine(days)
        }
    }
}

struct RecurringRuleEntity: Identifiable, Hashable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated var frequency: RecurrenceFrequency
    nonisolated var nextDate: Date
    nonisolated var isActive: Bool
    nonisolated var endDate: Date?
    nonisolated var templateAmount: Decimal
    nonisolated var templateNote: String?
    nonisolated var templateCategoryID: UUID?
    nonisolated var templateAccountID: UUID?
    nonisolated var templatePayeeID: UUID?
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        frequency: RecurrenceFrequency,
        nextDate: Date,
        isActive: Bool = true,
        endDate: Date? = nil,
        templateAmount: Decimal,
        templateNote: String? = nil,
        templateCategoryID: UUID? = nil,
        templateAccountID: UUID? = nil,
        templatePayeeID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.frequency = frequency
        self.nextDate = nextDate
        self.isActive = isActive
        self.endDate = endDate
        self.templateAmount = templateAmount
        self.templateNote = templateNote
        self.templateCategoryID = templateCategoryID
        self.templateAccountID = templateAccountID
        self.templatePayeeID = templatePayeeID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
