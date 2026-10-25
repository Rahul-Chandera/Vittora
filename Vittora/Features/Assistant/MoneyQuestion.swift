import Foundation
import VittoraCore

/// A question about the user's own money, as a query the app can answer from the ledger.
///
/// The on-device model only ever produces one of these. It never sees a total and never
/// states a figure: `MoneyAnswerEngine` computes every number from the user's records.
/// That is the same rule as the monthly summary (`SpendingSummaryService`): in a finance
/// app an invented number is worse than no answer.
struct MoneyQuestion: Equatable, Sendable {
    enum Measure: String, CaseIterable, Sendable {
        case spent, earned, topCategories, biggestExpense, transactionCount
    }

    enum Period: String, CaseIterable, Sendable {
        case today, thisWeek, thisMonth, lastMonth, last30Days, thisYear, lastYear

        /// The phrase that finishes an answer sentence: "You spent $42.00 this month."
        var phrase: String {
            switch self {
            case .today: String(localized: "today", comment: "Ends an answer: You spent $5 today.")
            case .thisWeek: String(localized: "this week", comment: "Ends an answer: You spent $5 this week.")
            case .thisMonth: String(localized: "this month", comment: "Ends an answer: You spent $5 this month.")
            case .lastMonth: String(localized: "last month", comment: "Ends an answer: You spent $5 last month.")
            case .last30Days: String(localized: "in the last 30 days", comment: "Ends an answer: You spent $5 in the last 30 days.")
            case .thisYear: String(localized: "this year", comment: "Ends an answer: You spent $5 this year.")
            case .lastYear: String(localized: "last year", comment: "Ends an answer: You spent $5 last year.")
            }
        }

        func dateRange(now: Date, calendar: Calendar) -> ClosedRange<Date> {
            let startOfToday = calendar.startOfDay(for: now)
            func interval(_ component: Calendar.Component, offset: Int = 0) -> ClosedRange<Date> {
                let anchor = calendar.date(byAdding: component, value: offset, to: now) ?? now
                guard let found = calendar.dateInterval(of: component, for: anchor) else { return startOfToday...now }
                return found.start...found.end.addingTimeInterval(-1)
            }
            switch self {
            case .today: return startOfToday...now
            case .thisWeek: return interval(.weekOfYear)
            case .thisMonth: return interval(.month)
            case .lastMonth: return interval(.month, offset: -1)
            case .last30Days:
                return (calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday)...now
            case .thisYear: return interval(.year)
            case .lastYear: return interval(.year, offset: -1)
            }
        }
    }

    var measure: Measure
    var period: Period
    /// Exact names from the user's own categories and payees, or nil.
    var categoryName: String?
    var payeeName: String?
}

/// Turns a typed question into a `MoneyQuestion` with keyword rules. Always available,
/// so the assistant works on devices without Apple Intelligence; where the model is
/// available it understands more ways of asking (`MoneyQuestionModelInterpreter`).
enum MoneyQuestionKeywordInterpreter {
    static func interpret(
        _ text: String,
        categoryNames: [String],
        payeeNames: [String]
    ) -> MoneyQuestion {
        let lower = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { lower.contains($0) } }

        let period: MoneyQuestion.Period =
            has("last month", "previous month") ? .lastMonth
            : has("last year", "previous year") ? .lastYear
            : has("this year", "year so far", "so far this year") ? .thisYear
            : has("today") ? .today
            : has("this week", "week") ? .thisWeek
            : has("30 days", "past month", "last 30") ? .last30Days
            : .thisMonth

        let measure: MoneyQuestion.Measure =
            has("earn", "income", "salary", "received", "got paid") ? .earned
            : has("biggest", "largest", "most expensive") ? .biggestExpense
            : has("top categor", "most on", "where does my money", "where did my money", "categories") ? .topCategories
            : has("how many") ? .transactionCount
            : .spent

        return MoneyQuestion(
            measure: measure,
            period: period,
            categoryName: longestName(in: lower, from: categoryNames),
            payeeName: longestName(in: lower, from: payeeNames)
        )
    }

    /// The longest of the user's names that appears in the question, so "Dining Out"
    /// wins over "Dining".
    static func longestName(in lowerText: String, from names: [String]) -> String? {
        names
            .filter { $0.count >= 3 && lowerText.contains($0.lowercased()) }
            .max { $0.count < $1.count }
    }
}
