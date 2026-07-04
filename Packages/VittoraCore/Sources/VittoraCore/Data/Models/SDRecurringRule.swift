import Foundation
import OSLog
import SwiftData

@Model
public final class SDRecurringRule {
    #Index<SDRecurringRule>([\.nextDate], [\.isActive])

    public var id: UUID = UUID()
    public var frequencyData: Data = Data()
    public var nextDate: Date = Date.now
    public var isActive: Bool = true
    public var endDate: Date?
    public var templateAmount: Decimal = 0
    public var templateNote: String?
    public var templateCategoryID: UUID?
    public var templateAccountID: UUID?
    public var templatePayeeID: UUID?
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    public init() {}

    public init(
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

    public var frequency: RecurrenceFrequency {
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
