import Foundation
import OSLog
import SwiftData

@Model
final class SDRecurringRule {
    #Index<SDRecurringRule>([\.nextDate], [\.isActive])

    @Attribute(.unique) var id: UUID = UUID()
    var frequencyData: Data = Data()
    var nextDate: Date = Date.now
    var isActive: Bool = true
    var endDate: Date?
    var templateAmount: Decimal = 0
    var templateNote: String?
    var templateCategoryID: UUID?
    var templateAccountID: UUID?
    var templatePayeeID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    init() {}

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

        do {
            self.frequencyData = try JSONEncoder().encode(frequency)
        } catch {
            Self.logger.error(
                "Failed to encode recurrence frequency during init: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    var frequency: RecurrenceFrequency {
        get {
            do {
                return try JSONDecoder().decode(RecurrenceFrequency.self, from: frequencyData)
            } catch {
                Self.logger.error(
                    "Failed to decode recurrence frequency: \(error.localizedDescription, privacy: .public)"
                )
                return .monthly
            }
        }
        set {
            do {
                frequencyData = try JSONEncoder().encode(newValue)
            } catch {
                Self.logger.error(
                    "Failed to encode recurrence frequency: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
