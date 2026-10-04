import Foundation

/// A tax-saving investment tracked to its maturity date (M2.4.5).
public struct Investment: Identifiable, Hashable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    /// Matches `India80CInstrument.id` when the user picked a known instrument, empty for
    /// anything they named themselves.
    public nonisolated var instrumentID: String
    public nonisolated var amount: Decimal
    public nonisolated var sectionKey: String
    public nonisolated var startDate: Date
    /// Nil where the lock-in is age-linked rather than a fixed term.
    public nonisolated var maturityDate: Date?
    public nonisolated var remindsOnMaturity: Bool
    public nonisolated var note: String?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    public nonisolated init(
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

    /// Whole days until maturity, negative once it has passed. Nil for an age-linked
    /// lock-in, which has no date to count towards.
    public nonisolated func daysToMaturity(from reference: Date = .now) -> Int? {
        guard let maturityDate else { return nil }
        let calendar = Calendar.current
        // Day granularity on both sides, so "matures today" is 0 rather than a few hours
        // either way depending on what time the record was created.
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: maturityDate)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    public nonisolated func hasMatured(asOf reference: Date = .now) -> Bool {
        guard let days = daysToMaturity(from: reference) else { return false }
        return days <= 0
    }
}
