import Foundation
import VittoraCore

struct YearInReviewUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let payeeRepository: any PayeeRepository
    let savingsGoalRepository: any SavingsGoalRepository

    func load(
        requestedYear: Int?,
        preferredCurrencyCode: String,
        today: Date,
        calendar: Calendar = .current
    ) async throws -> YearInReviewLoadResult {
        async let transactionsTask = transactionRepository.fetchAll(filter: nil)
        async let categoriesTask = categoryRepository.fetchAll()
        async let payeesTask = payeeRepository.fetchAll()
        async let goalsTask = savingsGoalRepository.fetchAll()

        let (transactions, categories, payees, goals) = try await (
            transactionsTask, categoriesTask, payeesTask, goalsTask
        )

        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.displayName) })
        let payeeNames = Dictionary(uniqueKeysWithValues: payees.map { ($0.id, $0.name) })
        let years = YearInReviewMath.availableYears(
            transactions: transactions,
            today: today,
            calendar: calendar
        )
        let ready = YearInReviewMath.isReady(
            transactions: transactions,
            today: today,
            calendar: calendar
        )

        guard ready else {
            return YearInReviewLoadResult(
                state: .thinHistory,
                availableYears: years,
                selectedYear: years.first,
                summary: nil
            )
        }

        guard let year = YearInReviewMath.resolveYear(
            requested: requestedYear,
            transactions: transactions,
            today: today,
            calendar: calendar
        ) else {
            return YearInReviewLoadResult(
                state: .thinHistory,
                availableYears: years,
                selectedYear: nil,
                summary: nil
            )
        }

        let summary = YearInReviewMath.summary(
            transactions: transactions,
            goals: goals,
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: year,
            preferredCurrencyCode: preferredCurrencyCode,
            today: today,
            calendar: calendar
        )

        if let summary {
            return YearInReviewLoadResult(
                state: .ready,
                availableYears: years,
                selectedYear: year,
                summary: summary
            )
        }

        // Selected year empty — try previous year with data.
        if let fallback = years.first(where: { $0 != year }),
           let fallbackSummary = YearInReviewMath.summary(
               transactions: transactions,
               goals: goals,
               categoryNames: categoryNames,
               payeeNames: payeeNames,
               year: fallback,
               preferredCurrencyCode: preferredCurrencyCode,
               today: today,
               calendar: calendar
           ) {
            return YearInReviewLoadResult(
                state: .ready,
                availableYears: years,
                selectedYear: fallback,
                summary: fallbackSummary
            )
        }

        return YearInReviewLoadResult(
            state: .emptyYear,
            availableYears: years,
            selectedYear: year,
            summary: nil
        )
    }
}

enum YearInReviewScreenState: Equatable, Sendable {
    case thinHistory
    case emptyYear
    case ready
}

struct YearInReviewLoadResult: Equatable, Sendable {
    let state: YearInReviewScreenState
    let availableYears: [Int]
    let selectedYear: Int?
    let summary: YearInReviewSummary?
}
