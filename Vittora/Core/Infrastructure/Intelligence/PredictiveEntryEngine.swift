import Foundation
import VittoraCore

/// Suggests transaction details from the user's own patterns (M3.2.7).
///
/// The plan describes this as "suggest transaction details based on time,
/// location, patterns". Location is deliberately absent: Vittora asks for no
/// location permission today, and adding one to sharpen a form suggestion would
/// trade a real privacy cost for a small convenience. Time and payee patterns
/// are already in the ledger and cost the user nothing.
///
/// Pure and rules-based. Per the scope note this only ever suggests — the form
/// pre-fills and the user overwrites freely.
nonisolated struct PredictiveEntryEngine: Sendable {

    /// A pattern needs this many matching transactions before it is offered.
    /// Two coincidences are a coincidence.
    nonisolated static let minimumOccurrences = 3

    /// The share of a payee's transactions that must agree before an amount is
    /// suggested. Below this the payee varies too much to guess.
    nonisolated static let amountAgreementThreshold = 0.6

    nonisolated struct Suggestion: Sendable, Equatable {
        nonisolated let payeeID: UUID?
        nonisolated let categoryID: UUID?
        nonisolated let amount: Decimal?
        /// Why this is being offered, shown to the user rather than presenting
        /// the guess as fact.
        nonisolated let reason: String
        nonisolated let occurrences: Int

        nonisolated var isEmpty: Bool {
            payeeID == nil && categoryID == nil && amount == nil
        }
    }

    nonisolated struct Observation: Sendable {
        nonisolated let payeeID: UUID?
        nonisolated let categoryID: UUID?
        nonisolated let amount: Decimal
        nonisolated let date: Date

        nonisolated init(payeeID: UUID?, categoryID: UUID?, amount: Decimal, date: Date) {
            self.payeeID = payeeID
            self.categoryID = categoryID
            self.amount = amount
            self.date = date
        }
    }

    /// What the user usually does at this hour on this weekday.
    ///
    /// Matched on weekday AND a three-hour window rather than exact time: a
    /// coffee bought at 08:12 and 08:47 is the same habit, and an exact match
    /// would find nothing.
    nonisolated func suggest(
        at moment: Date,
        history: [Observation],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Suggestion? {
        let weekday = calendar.component(.weekday, from: moment)
        let hour = calendar.component(.hour, from: moment)

        let matching = history.filter { observation in
            let sameWeekday = calendar.component(.weekday, from: observation.date) == weekday
            let observedHour = calendar.component(.hour, from: observation.date)
            return sameWeekday && abs(observedHour - hour) <= 1
        }
        guard matching.count >= Self.minimumOccurrences else { return nil }

        // The most common payee in that slot, with ties broken by UUID so the
        // suggestion does not change between launches on identical data.
        let payeeID = Self.mostCommon(matching.map(\.payeeID))
        let categoryID = Self.mostCommon(matching.map(\.categoryID))

        // Only suggest an amount when the payee is consistent about it. A payee
        // whose charges vary has no "usual" amount, and filling one in would be
        // a number the user has to check and correct every time.
        let amount = Self.consistentAmount(
            matching.filter { payeeID == nil || $0.payeeID == payeeID }.map(\.amount)
        )

        let suggestion = Suggestion(
            payeeID: payeeID,
            categoryID: categoryID,
            amount: amount,
            reason: String(localized: "You usually record this around now."),
            occurrences: matching.count
        )
        return suggestion.isEmpty ? nil : suggestion
    }

    /// The modal value, requiring a strict majority of non-nil entries.
    /// Deterministic on ties.
    nonisolated static func mostCommon(_ values: [UUID?]) -> UUID? {
        let present = values.compactMap { $0 }
        guard !present.isEmpty else { return nil }

        var counts: [UUID: Int] = [:]
        for value in present { counts[value, default: 0] += 1 }

        var best: (id: UUID, count: Int)?
        for (id, count) in counts {
            guard let current = best else { best = (id, count); continue }
            if count > current.count || (count == current.count && id.uuidString < current.id.uuidString) {
                best = (id, count)
            }
        }
        guard let winner = best else { return nil }
        // A bare plurality across many options is not a pattern.
        guard Double(winner.count) / Double(present.count) >= 0.5 else { return nil }
        return winner.id
    }

    /// The median, offered only when the values cluster tightly enough that one
    /// number represents them. Median rather than mean so a single unusual
    /// charge does not set the suggestion.
    nonisolated static func consistentAmount(_ amounts: [Decimal]) -> Decimal? {
        guard amounts.count >= minimumOccurrences else { return nil }
        let median = SpendingAnomalyEngine.median(amounts)
        guard median > 0 else { return nil }

        // Within 20% of the median counts as agreeing.
        let toleranceFraction = Decimal(string: "0.2") ?? 0
        let tolerance = median * toleranceFraction
        let agreeing = amounts.filter { abs($0 - median) <= tolerance }.count
        guard Double(agreeing) / Double(amounts.count) >= amountAgreementThreshold else { return nil }
        return median
    }
}
