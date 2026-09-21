import Foundation
import SwiftData

/// A tax-saving investment the user is tracking to its maturity date (M2.4.5).
///
/// Every attribute carries a default and nothing is required, because CloudKit cannot
/// evolve a mirrored record type for a non-optional attribute with no default — that
/// breaks sync for every existing user, and `MigrationPlanSchemaTests` fails the build if
/// it is ever violated.
@Model
public final class SDInvestment {
    #Index<SDInvestment>([\.maturityDate])

    public var id: UUID = UUID()
    public var name: String = ""
    /// Matches `India80CInstrument.id` when the user picked one of the known instruments,
    /// empty for anything they typed themselves. Not a relationship: the instrument table
    /// is shipped reference data, not rows, so a foreign key would have nothing to point at.
    public var instrumentID: String = ""
    public var amount: Decimal = Decimal(0)
    public var sectionKey: String = ""
    public var startDate: Date = Date.now
    /// Nil where the lock-in is age-linked rather than a fixed term — NPS Tier-I runs to
    /// age 60, which is not a date this record can know.
    public var maturityDate: Date? = nil
    public var remindsOnMaturity: Bool = true
    public var note: String? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}

    public init(
        id: UUID = UUID(),
        name: String,
        instrumentID: String = "",
        amount: Decimal,
        sectionKey: String = "",
        startDate: Date = .now,
        maturityDate: Date? = nil,
        remindsOnMaturity: Bool = true,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.instrumentID = instrumentID
        self.amount = amount
        self.sectionKey = sectionKey
        self.startDate = startDate
        self.maturityDate = maturityDate
        self.remindsOnMaturity = remindsOnMaturity
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
