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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

struct RecurringRuleEntity: Identifiable, Hashable, Equatable, Sendable {
    let id: UUID
    var frequency: RecurrenceFrequency
    var nextDate: Date
    var isActive: Bool
    var endDate: Date?
    var templateAmount: Decimal
    var templateNote: String?
    var templateCategoryID: UUID?
    var templateAccountID: UUID?
    var templatePayeeID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
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
