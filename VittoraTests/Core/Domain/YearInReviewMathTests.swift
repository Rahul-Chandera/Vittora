import Foundation
import Testing
import VittoraCore

@Suite("Year in Review Math")
struct YearInReviewMathTests {
    private let calendar = yearInReviewCalendar
    private let today = yearInReviewDate(year: 2026, month: 7, day: 27)
    private let rentID = UUID()
    private let groceriesID = UUID()
    private let diningID = UUID()
    private let payeeA = UUID()
    private let payeeB = UUID()

    private var categoryNames: [UUID: String] {
        [rentID: "Rent", groceriesID: "Groceries", diningID: "Dining"]
    }

    private var payeeNames: [UUID: String] {
        [payeeA: "Whole Foods", payeeB: "DoorDash"]
    }

    // MARK: - Year total & categories

    @Test("year total sums each expense from its own column")
    func yearTotal() throws {
        let transactions = sampleYearExpenses()
        let summary = try #require(YearInReviewMath.summary(
            transactions: transactions,
            goals: [],
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))

        let expected = Decimal(string: "100.50")! + Decimal(string: "200.25")! + 50
        #expect(summary.totalSpent == expected)
        #expect(summary.totalSpent == Decimal(string: "350.75")!)
    }

    @Test("top categories plus Other sum to year total and shares sum to 100")
    func topCategoriesReconcile() throws {
        let transactions = [
            expense(amount: "1000", month: 1, day: 1, category: rentID),
            expense(amount: "200", month: 2, day: 1, category: groceriesID),
            expense(amount: "150", month: 3, day: 1, category: diningID),
            expense(amount: "80", month: 4, day: 1, category: groceriesID),
            expense(amount: "40", month: 5, day: 1, category: diningID),
            expense(amount: "30", month: 6, day: 1, category: diningID),
        ]
        // Force Other rollup with many tiny categories
        let extraIDs = (0..<6).map { _ in UUID() }
        var names = categoryNames
        var extras: [TransactionEntity] = []
        for (index, id) in extraIDs.enumerated() {
            names[id] = "Cat\(index)"
            extras.append(expense(amount: "10", month: 7, day: index + 1, category: id))
        }

        let summary = try #require(YearInReviewMath.summary(
            transactions: transactions + extras,
            goals: [],
            categoryNames: names,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))

        #expect(YearInReviewMath.displayedCategoryAmountsSumToTotal(
            categories: summary.topCategories,
            totalSpent: summary.totalSpent
        ))
        #expect(YearInReviewMath.displayedSharesSumTo100(categories: summary.topCategories))
        #expect(summary.topCategories.contains(where: { $0.name == "Other" }))
    }

    @Test("displayed percentage shares use largest remainder and sum to 100")
    func percentageShares() {
        let amounts = [
            Decimal(3700),
            Decimal(string: "707.60")!,
            Decimal(string: "197.70")!,
            Decimal(string: "189.99")!,
            Decimal(string: "396.73")!,
        ]
        let shares = YearInReviewMath.displayedPercentageShares(amounts: amounts)
        #expect(shares.reduce(0, +) == 100)
        #expect(shares.count == 5)
        #expect(shares[0] == 71)
    }

    // MARK: - Biggest month, streak, savings

    @Test("biggest month picks the highest spend month and its top category")
    func biggestMonth() throws {
        let transactions = [
            expense(amount: "100", month: 1, day: 5, category: rentID),
            expense(amount: "500", month: 3, day: 5, category: groceriesID),
            expense(amount: "50", month: 3, day: 6, category: diningID),
            expense(amount: "200", month: 6, day: 5, category: rentID),
        ]
        let summary = try #require(YearInReviewMath.summary(
            transactions: transactions,
            goals: [],
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))
        let highlight = try #require(summary.biggestMonth)
        #expect(calendar.component(.month, from: highlight.monthStart) == 3)
        #expect(highlight.amount == 550)
        #expect(highlight.topCategoryName == "Groceries")
        #expect(highlight.topCategoryAmount == 500)
    }

    @Test("longest streak counts consecutive calendar days with any transaction")
    func streakCalculation() {
        let transactions = [
            expense(amount: "10", month: 7, day: 1, category: diningID),
            expense(amount: "10", month: 7, day: 2, category: diningID),
            expense(amount: "10", month: 7, day: 3, category: diningID),
            expense(amount: "10", month: 7, day: 5, category: diningID),
            expense(amount: "10", month: 7, day: 6, category: diningID),
        ]
        #expect(YearInReviewMath.longestStreakDays(in: transactions, calendar: calendar) == 3)
    }

    @Test("savings totals sum tagged contributions and count completed goals")
    func savingsTotals() throws {
        let contribution = TransactionEntity(
            amount: 600,
            date: yearInReviewDate(year: 2026, month: 7, day: 12),
            type: .adjustment,
            currencyCode: "USD",
            tags: [YearInReviewMath.savingsContributionTag]
        )
        let goals = [
            SavingsGoalEntity(name: "Trip", targetAmount: 5_000, currentAmount: 1_800),
            SavingsGoalEntity(
                name: "Done",
                targetAmount: 100,
                currentAmount: 100,
                status: .achieved
            ),
        ]
        let summary = try #require(YearInReviewMath.summary(
            transactions: sampleYearExpenses() + [contribution],
            goals: goals,
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))
        #expect(summary.savingsContributed == 600)
        #expect(summary.goalsCompleted == 1)
    }

    // MARK: - Multi-currency & edge years

    @Test("multi-currency scopes to preferred currency and never mixes amounts")
    func multiCurrencyHandling() throws {
        let usd = [
            expense(amount: "100", month: 1, day: 1, category: rentID, currency: "USD"),
            expense(amount: "50", month: 2, day: 1, category: groceriesID, currency: "USD"),
        ]
        let eur = [
            expense(amount: "999", month: 3, day: 1, category: diningID, currency: "EUR"),
        ]
        let summary = try #require(YearInReviewMath.summary(
            transactions: usd + eur,
            goals: [],
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))
        #expect(summary.currencyCode == "USD")
        #expect(summary.scopedToPrimaryCurrency)
        #expect(summary.totalSpent == 150)
        #expect(!summary.topCategories.contains(where: { $0.amount == 999 }))
    }

    @Test("single-transaction year still produces a summary")
    func singleTransactionYear() throws {
        let transactions = [
            expense(amount: "42.50", month: 4, day: 10, category: diningID),
        ]
        let summary = try #require(YearInReviewMath.summary(
            transactions: transactions,
            goals: [],
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))
        #expect(summary.totalSpent == Decimal(string: "42.50")!)
        #expect(summary.transactionCount == 1)
        #expect(YearInReviewMath.displayedCategoryAmountsSumToTotal(
            categories: summary.topCategories,
            totalSpent: summary.totalSpent
        ))
        #expect(YearInReviewMath.displayedSharesSumTo100(categories: summary.topCategories))
    }

    @Test("empty year returns nil; resolveYear falls back to previous year with data")
    func emptyYear() {
        let transactions = [
            expense(amount: "20", month: 6, day: 1, category: diningID, year: 2025),
            expense(amount: "30", month: 8, day: 1, category: diningID, year: 2025),
        ]
        #expect(YearInReviewMath.summary(
            transactions: transactions,
            goals: [],
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ) == nil)

        let resolved = YearInReviewMath.resolveYear(
            requested: 2026,
            transactions: transactions,
            today: today,
            calendar: calendar
        )
        #expect(resolved == 2025)
    }

    @Test("thin history is not ready; twenty transactions across two months is ready")
    func readinessGate() {
        let thin = (1...19).map { day in
            expense(amount: "1", month: 7, day: min(day, 27), category: diningID)
        }
        #expect(!YearInReviewMath.isReady(transactions: thin, today: today, calendar: calendar))

        var ready: [TransactionEntity] = []
        for day in 1...10 {
            ready.append(expense(amount: "1", month: 6, day: day, category: diningID))
        }
        for day in 1...10 {
            ready.append(expense(amount: "1", month: 7, day: day, category: diningID))
        }
        #expect(YearInReviewMath.isReady(transactions: ready, today: today, calendar: calendar))
    }

    @Test("US demo fixture figures match hand-computed year total and top categories")
    func usDemoHandComputedFigures() throws {
        // Anchored to calendar months relative to today (same as UITestDataSeeder).
        let d: (String) -> Decimal = { Decimal(string: $0)! }
        let fixture = USDemoYearInReviewFixture.make(
            today: today,
            calendar: calendar
        )
        let summary = try #require(YearInReviewMath.summary(
            transactions: fixture.transactions,
            goals: fixture.goals,
            categoryNames: fixture.categoryNames,
            payeeNames: fixture.payeeNames,
            year: 2026,
            preferredCurrencyCode: "USD",
            today: today,
            calendar: calendar
        ))

        // Hand-computed from UITestDataSeeder US expense rows + $200 borrowed-debt
        // settlement (SettleDebtUseCase, uncategorized). Incomes excluded.
        // Rent 1850+1850=3700; Groceries 128.40+142.10+89.65+132.80+118.25+96.40=707.60;
        // Uncategorized (debt settlement)=200; Utilities 96.20+101.50=197.70;
        // Other (Shopping+Dining+Transport+Entertainment+Subscriptions+Health)=586.72;
        // year total = 5392.02. Shares via largest-remainder: 68/13/4/4/11.
        #expect(summary.totalSpent == d("5392.02"))
        #expect(summary.topCategories.map(\.name) == [
            "Rent", "Groceries", "Uncategorized", "Utilities", "Other",
        ])
        #expect(summary.topCategories.map(\.amount) == [
            3_700, d("707.60"), 200, d("197.70"), d("586.72"),
        ])
        #expect(summary.topCategories.map(\.sharePercent) == [68, 13, 4, 4, 11])
        #expect(YearInReviewMath.displayedCategoryAmountsSumToTotal(
            categories: summary.topCategories,
            totalSpent: summary.totalSpent
        ))
        #expect(YearInReviewMath.displayedSharesSumTo100(categories: summary.topCategories))
    }

    // MARK: - Helpers

    private func sampleYearExpenses() -> [TransactionEntity] {
        [
            expense(amount: "100.50", month: 1, day: 3, category: rentID, payee: nil),
            expense(amount: "200.25", month: 3, day: 8, category: groceriesID, payee: payeeA),
            expense(amount: "50", month: 7, day: 4, category: diningID, payee: payeeB),
        ]
    }

    private func expense(
        amount: String,
        month: Int,
        day: Int,
        category: UUID,
        payee: UUID? = nil,
        currency: String = "USD",
        year: Int = 2026
    ) -> TransactionEntity {
        TransactionEntity(
            amount: Decimal(string: amount)!,
            date: yearInReviewDate(year: year, month: month, day: day),
            type: .expense,
            currencyCode: currency,
            categoryID: category,
            payeeID: payee
        )
    }

}

private let yearInReviewCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func yearInReviewDate(year: Int, month: Int, day: Int) -> Date {
    yearInReviewCalendar.date(from: DateComponents(year: year, month: month, day: day))
        ?? Date(timeIntervalSince1970: 0)
}

/// Mirrors the US expense rows in `UITestDataSeeder.seedDemoShowcaseIfNeeded` (USD branch),
/// anchored the same way: previous calendar month + current calendar month relative to `today`.
enum USDemoYearInReviewFixture {
    struct Result {
        let transactions: [TransactionEntity]
        let goals: [SavingsGoalEntity]
        let categoryNames: [UUID: String]
        let payeeNames: [UUID: String]
        let rentID: UUID
        let groceriesID: UUID
        let utilitiesID: UUID
        let diningID: UUID
        let subscriptionsID: UUID
        let transportID: UUID
        let shoppingID: UUID
        let entertainmentID: UUID
        let healthID: UUID
        let doorDashID: UUID
        let wholeFoodsID: UUID
    }

    static func make(today: Date, calendar: Calendar) -> Result {
        let rentID = UUID()
        let groceriesID = UUID()
        let utilitiesID = UUID()
        let diningID = UUID()
        let subscriptionsID = UUID()
        let transportID = UUID()
        let shoppingID = UUID()
        let entertainmentID = UUID()
        let healthID = UUID()
        let doorDashID = UUID()
        let wholeFoodsID = UUID()

        let categoryNames: [UUID: String] = [
            rentID: "Rent",
            groceriesID: "Groceries",
            utilitiesID: "Utilities",
            diningID: "Dining",
            subscriptionsID: "Subscriptions",
            transportID: "Transport",
            shoppingID: "Shopping",
            entertainmentID: "Entertainment",
            healthID: "Health",
        ]
        let payeeNames: [UUID: String] = [
            doorDashID: "DoorDash",
            wholeFoodsID: "Whole Foods",
        ]

        func monthDay(_ monthOffset: Int, _ day: Int) -> Date {
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let month = calendar.date(byAdding: .month, value: monthOffset, to: start)!
            let date = calendar.date(byAdding: .day, value: day - 1, to: month)!
            return min(date, today)
        }

        let d: (String) -> Decimal = { Decimal(string: $0)! }
        typealias Row = (Decimal, Int, Int, UUID, UUID?)
        let rows: [Row] = [
            (1_850, -1, 2, rentID, nil),
            (d("128.40"), -1, 5, groceriesID, wholeFoodsID),
            (d("96.20"), -1, 9, utilitiesID, nil),
            (d("42.75"), -1, 11, diningID, doorDashID),
            (d("142.10"), -1, 14, groceriesID, wholeFoodsID),
            (d("15.49"), -1, 15, subscriptionsID, nil),
            (d("48.30"), -1, 19, transportID, nil),
            (d("89.65"), -1, 24, groceriesID, wholeFoodsID),
            (d("28.90"), -1, 27, diningID, doorDashID),
            (1_850, 0, 2, rentID, nil),
            (d("132.80"), 0, 3, groceriesID, wholeFoodsID),
            (d("101.50"), 0, 5, utilitiesID, nil),
            (d("36.40"), 0, 6, diningID, doorDashID),
            (d("189.99"), 0, 7, shoppingID, nil),
            (d("118.25"), 0, 8, groceriesID, wholeFoodsID),
            (d("24.50"), 0, 9, transportID, nil),
            (d("15.49"), 0, 10, subscriptionsID, nil),
            (d("54.20"), 0, 11, diningID, doorDashID),
            (32, 0, 11, entertainmentID, nil),
            (d("52.75"), 0, 12, transportID, nil),
            (d("96.40"), 0, 13, groceriesID, wholeFoodsID),
            (d("27.35"), 0, 13, healthID, nil),
            (d("18.60"), 0, 14, diningID, doorDashID),
        ]

        let transactions = rows.map { row in
            TransactionEntity(
                amount: row.0,
                date: monthDay(row.1, row.2),
                type: .expense,
                currencyCode: "USD",
                categoryID: row.3,
                payeeID: row.4
            )
        }
        // Mirrors SettleDebtUseCase for the borrowed demo debt ($200 expense, no category).
        let debtSettlement = TransactionEntity(
            amount: 200,
            date: monthDay(0, 12),
            note: "Settlement: Moving costs",
            type: .expense,
            currencyCode: "USD",
            tags: ["debt-settlement"]
        )

        let goals = [
            SavingsGoalEntity(
                name: "Emergency Fund",
                category: .emergency,
                targetAmount: 15_000,
                currentAmount: 9_500,
                isEmergencyFund: true
            ),
            SavingsGoalEntity(
                name: "Hawaii Trip",
                category: .travel,
                targetAmount: 5_000,
                currentAmount: 1_800
            ),
        ]

        return Result(
            transactions: transactions + [debtSettlement],
            goals: goals,
            categoryNames: categoryNames,
            payeeNames: payeeNames,
            rentID: rentID,
            groceriesID: groceriesID,
            utilitiesID: utilitiesID,
            diningID: diningID,
            subscriptionsID: subscriptionsID,
            transportID: transportID,
            shoppingID: shoppingID,
            entertainmentID: entertainmentID,
            healthID: healthID,
            doorDashID: doorDashID,
            wholeFoodsID: wholeFoodsID
        )
    }
}
