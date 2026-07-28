import Foundation
import Testing
import SwiftUI
import VittoraCore
@testable import Vittora

@Suite("Year in Review Share Image")
@MainActor
struct YearInReviewShareImageTests {
    @Test("shared image text contains no amounts when include-amounts is off")
    func shareImageOmitsAmountsByDefault() throws {
        let summary = sampleSummary()
        let amountStrings = [
            CurrencyFormatter.format(summary.totalSpent, currencyCode: "USD"),
            CurrencyFormatter.format(summary.topCategories[0].amount, currencyCode: "USD"),
            CurrencyFormatter.format(summary.topCategories[1].amount, currencyCode: "USD"),
        ]

        let privateLines = YearInReviewShareImageRenderer.renderedTextLines(
            summary: summary,
            includeAmounts: false
        )
        for amount in amountStrings {
            #expect(!privateLines.contains(where: { $0.contains(amount) }))
        }
        #expect(privateLines.contains(where: { $0.contains("Made with Vittora") }))
        #expect(privateLines.allSatisfy { !YearInReviewShareCopy.containsCurrencyAmount($0, currencyCode: "USD") })

        // Render the actual share image so the privacy path is exercised end-to-end.
        let url = try YearInReviewShareImageRenderer.render(
            summary: summary,
            includeAmounts: false
        )
        let bytes = try Data(contentsOf: url)
        #expect(!bytes.isEmpty)
        // PNG magic
        #expect(bytes.starts(with: Data([0x89, 0x50, 0x4E, 0x47])))

        // With amounts on, the same figures must appear in the text inventory
        // that feeds the renderer (proves the off-path isn't vacuously empty).
        let publicLines = YearInReviewShareImageRenderer.renderedTextLines(
            summary: summary,
            includeAmounts: true
        )
        for amount in amountStrings {
            #expect(publicLines.contains(where: { $0.contains(amount) }))
        }

        let publicURL = try YearInReviewShareImageRenderer.render(
            summary: summary,
            includeAmounts: true
        )
        #expect(try Data(contentsOf: publicURL) != bytes)
    }

    @Test("include-amounts toggle defaults to off on the view model")
    func includeAmountsDefaultsOff() {
        let vm = YearInReviewViewModel(
            useCase: YearInReviewUseCase(
                transactionRepository: MockTransactionRepository(),
                categoryRepository: MockCategoryRepository(),
                payeeRepository: MockPayeeRepository(),
                savingsGoalRepository: MockSavingsGoalRepository()
            ),
            preferredCurrencyCode: "USD"
        )
        #expect(vm.includeAmountsInShare == false)
    }

    private func sampleSummary() -> YearInReviewSummary {
        let month = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 1)
        ) ?? .now
        return YearInReviewSummary(
            year: 2026,
            currencyCode: "USD",
            scopedToPrimaryCurrency: false,
            totalSpent: Decimal(string: "5192.02")!,
            monthlySpend: [
                YearInReviewMonthlyPoint(monthStart: month, amount: Decimal(string: "2750.23")!),
            ],
            topCategories: [
                YearInReviewCategoryShare(name: "Rent", amount: 3_700, sharePercent: 71),
                YearInReviewCategoryShare(
                    name: "Groceries",
                    amount: Decimal(string: "707.60")!,
                    sharePercent: 14
                ),
                YearInReviewCategoryShare(
                    name: "Other",
                    amount: Decimal(string: "784.42")!,
                    sharePercent: 15
                ),
            ],
            biggestMonth: YearInReviewMonthHighlight(
                monthStart: month,
                amount: Decimal(string: "2750.23")!,
                topCategoryName: "Rent",
                topCategoryAmount: 1_850
            ),
            topPayees: [
                YearInReviewPayeeShare(name: "Whole Foods", amount: Decimal(string: "707.60")!),
            ],
            savingsContributed: 600,
            goalsCompleted: 0,
            longestStreakDays: 4,
            transactionCount: 26,
            firstTransactionDate: month
        )
    }
}
