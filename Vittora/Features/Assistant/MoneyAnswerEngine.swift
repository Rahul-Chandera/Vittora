import Foundation
import VittoraCore

/// The answer to a `MoneyQuestion`, computed from the ledger and stated in a fixed
/// sentence. Nothing here comes from a language model.
struct MoneyAnswer: Equatable, Sendable {
    let text: String
    /// The transactions behind the answer, newest first, at most `MoneyAnswerEngine.listLimit`.
    let transactions: [TransactionEntity]
}

struct MoneyAnswerEngine: Sendable {
    static let listLimit = 20

    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let payeeRepository: any PayeeRepository

    func answer(
        _ question: MoneyQuestion,
        currencyCode: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws -> MoneyAnswer {
        let categories = try await categoryRepository.fetchAll()
        let payees = try await payeeRepository.fetchAll()
        let category = question.categoryName.flatMap { name in
            categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        let payee = question.payeeName.flatMap { name in
            payees.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }

        let type: TransactionType = question.measure == .earned ? .income : .expense
        var filter = TransactionFilter(
            dateRange: question.period.dateRange(now: now, calendar: calendar),
            types: [type]
        )
        if let category {
            // A parent category includes its sub-categories.
            let ids = Set([category.id] + categories.filter { $0.parentID == category.id }.map(\.id))
            filter.categoryIDs = ids
        }
        if let payee { filter.payeeIDs = [payee.id] }

        let all = try await transactionRepository.fetchAll(filter: filter)
        // Figures are in the user's currency only. Adding amounts in different
        // currencies would produce a number that means nothing.
        let matching = all.filter { $0.currencyCode == currencyCode }
        let otherCurrencies = all.count != matching.count
        let newestFirst = matching.sorted { $0.date > $1.date }
        let total = matching.reduce(Decimal(0)) { $0 + $1.amount }
        let period = question.period.phrase
        func money(_ value: Decimal) -> String { CurrencyFormatter.format(value, currencyCode: currencyCode) }

        var text: String
        switch question.measure {
        case .spent:
            if matching.isEmpty {
                text = String(localized: "No spending recorded \(period).")
            } else if let category {
                text = String(localized: "You spent \(money(total)) on \(category.name) \(period).")
            } else if let payee {
                text = String(localized: "You spent \(money(total)) at \(payee.name) \(period).")
            } else {
                text = String(localized: "You spent \(money(total)) \(period).")
            }
        case .earned:
            text = matching.isEmpty
                ? String(localized: "No income recorded \(period).")
                : String(localized: "You received \(money(total)) in income \(period).")
        case .transactionCount:
            text = String(localized: "You recorded \(matching.count) expenses \(period).")
        case .biggestExpense:
            if let biggest = matching.max(by: { $0.amount < $1.amount }) {
                let date = biggest.date.formatted(date: .abbreviated, time: .omitted)
                if let name = payees.first(where: { $0.id == biggest.payeeID })?.name {
                    text = String(localized: "Your biggest expense \(period) was \(money(biggest.amount)) at \(name), on \(date).")
                } else {
                    text = String(localized: "Your biggest expense \(period) was \(money(biggest.amount)), on \(date).")
                }
                return MoneyAnswer(text: text + Self.currencyNote(otherCurrencies), transactions: [biggest])
            }
            text = String(localized: "No spending recorded \(period).")
        case .topCategories:
            let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            let totals = Dictionary(grouping: matching) { $0.categoryID }
                .map { (name: $0.key.flatMap { names[$0] } ?? String(localized: "Uncategorized"),
                        total: $0.value.reduce(Decimal(0)) { $0 + $1.amount }) }
                .sorted { $0.total > $1.total }
                .prefix(3)
            if totals.isEmpty {
                text = String(localized: "No spending recorded \(period).")
            } else {
                let list = totals.map { "\($0.name) \(money($0.total))" }.formatted(.list(type: .and))
                text = String(localized: "Your top categories \(period): \(list).")
            }
        }
        return MoneyAnswer(
            text: text + Self.currencyNote(otherCurrencies),
            transactions: Array(newestFirst.prefix(Self.listLimit))
        )
    }

    private static func currencyNote(_ otherCurrencies: Bool) -> String {
        otherCurrencies ? " " + String(localized: "Transactions in other currencies aren't included.") : ""
    }
}
