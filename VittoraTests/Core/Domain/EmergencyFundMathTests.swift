import Foundation
import Testing
import VittoraCore

@Suite("Emergency Fund Math")
struct EmergencyFundMathTests {
    private let needsID = UUID()
    private let wantsID = UUID()
    private let today = emergencyFundDate(year: 2026, month: 7, day: 21)

    @Test("recurring needs are normalized monthly and take priority")
    func recurringBaseline() throws {
        let weekly = RecurringRuleEntity(
            frequency: .weekly,
            nextDate: today,
            templateAmount: 100,
            templateCategoryID: needsID
        )
        let want = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: today,
            templateAmount: 999,
            templateCategoryID: wantsID
        )

        let baseline = try #require(EmergencyFundMath.recurringBaseline(
            rules: [weekly, want],
            needsCategoryIDs: [needsID],
            today: today
        ))

        #expect(baseline.monthlyAmount == Decimal(100) * 52 / 12)
        #expect(baseline.source == .recurringRules)
    }

    @Test("history fallback averages the available two-month window")
    func shortHistoryUsesAvailableMonths() throws {
        let january = emergencyFundDate(year: 2026, month: 1, day: 10)
        let february = emergencyFundDate(year: 2026, month: 2, day: 10)
        let transactions = [
            TransactionEntity(amount: 300, date: january, type: .expense, categoryID: needsID),
            TransactionEntity(amount: 500, date: february, type: .expense, categoryID: needsID),
            TransactionEntity(amount: 10_000, date: february, type: .expense, categoryID: wantsID),
        ]

        let baseline = try #require(EmergencyFundMath.historyBaseline(
            transactions: transactions,
            needsCategoryIDs: [needsID],
            today: today,
            calendar: emergencyFundCalendar
        ))

        #expect(baseline.monthlyAmount == 400)
        #expect(baseline.source == .spendingHistory(monthCount: 2))
    }

    @Test("neither source available returns no baseline")
    func neitherSource() {
        #expect(EmergencyFundMath.recurringBaseline(
            rules: [],
            needsCategoryIDs: [needsID],
            today: today
        ) == nil)
        #expect(EmergencyFundMath.historyBaseline(
            transactions: [],
            needsCategoryIDs: [needsID],
            today: today,
            calendar: emergencyFundCalendar
        ) == nil)
    }

    @Test("zero essentials does not divide")
    func zeroEssentials() {
        #expect(EmergencyFundMath.coverageMonths(currentFund: 5_000, essentialMonthly: 0) == nil)
    }

    @Test("coverage status has all three bands")
    func statusBands() {
        #expect(EmergencyFundMath.status(for: Decimal(string: "2.9")!) == .buildUp)
        #expect(EmergencyFundMath.status(for: 3) == .onTrack)
        #expect(EmergencyFundMath.status(for: 6) == .onTrack)
        #expect(EmergencyFundMath.status(for: Decimal(string: "6.1")!) == .comfortable)
    }

    @Test("three displayed figures reconcile within one-decimal coverage rounding")
    func displayedFiguresReconcile() throws {
        let baseline = EmergencyFundBaseline(monthlyAmount: 1_850, source: .recurringRules)
        let snapshot = try #require(EmergencyFundMath.snapshot(
            currentFund: 9_500,
            baseline: baseline
        ))

        #expect(snapshot.coverageMonths == Decimal(string: "5.1")!)
        #expect(EmergencyFundMath.displayedFiguresReconcile(
            currentFund: snapshot.currentFund,
            essentialMonthly: snapshot.essentialMonthly,
            coverageMonths: snapshot.coverageMonths
        ))
    }

    @Test("current fund sums selected account balances and flagged goals independently")
    func currentFundSources() {
        let selected = AccountEntity(name: "Savings", type: .bank, balance: 4_200)
        let ignored = AccountEntity(name: "Checking", type: .bank, balance: 7_000)
        let fundGoal = SavingsGoalEntity(
            name: "Buffer",
            targetAmount: 15_000,
            currentAmount: 9_500,
            isEmergencyFund: true
        )
        let otherGoal = SavingsGoalEntity(
            name: "Travel",
            targetAmount: 5_000,
            currentAmount: 1_800
        )

        // Same expectation, expressed through the currency-scoped signature.
        // These accounts use the default currency, so nothing is excluded.
        #expect(EmergencyFundMath.currentFund(
            accounts: [selected, ignored],
            selectedAccountIDs: [selected.id],
            goals: [fundGoal, otherGoal],
            currencyCode: CurrencyDefaults.code
        ) == 13_700)
    }

    /// The fund is counted in one currency.
    ///
    /// This was the third place summing balances across currencies, after
    /// CalculateNetWorthUseCase and CashFlowForecastUseCase. Owner decision
    /// (2026-08-17): goals count as display-currency — SavingsGoalEntity has no
    /// currencyCode — and contributing accounts are scoped to match.
    @Test("an account in another currency is not added to the fund")
    func foreignCurrencyAccountIsExcluded() {
        let home = AccountEntity(name: "Savings", type: .bank, balance: 4_200, currencyCode: "USD")
        let foreign = AccountEntity(name: "ICICI", type: .bank, balance: 100_000, currencyCode: "INR")
        let fundGoal = SavingsGoalEntity(
            name: "Buffer",
            targetAmount: 15_000,
            currentAmount: 9_500,
            isEmergencyFund: true
        )

        let total = EmergencyFundMath.currentFund(
            accounts: [home, foreign],
            selectedAccountIDs: [home.id, foreign.id],
            goals: [fundGoal],
            currencyCode: "USD"
        )

        // 4_200 + 9_500, with the INR balance left out entirely.
        #expect(total == 13_700)
        // The bug: 100_000 added straight onto a dollar total.
        #expect(total != 113_700)
    }

    @Test("goals count regardless of the account currency in play")
    func goalsAreDisplayCurrency() {
        let foreign = AccountEntity(name: "ICICI", type: .bank, balance: 100_000, currencyCode: "INR")
        let fundGoal = SavingsGoalEntity(
            name: "Buffer",
            targetAmount: 15_000,
            currentAmount: 9_500,
            isEmergencyFund: true
        )

        // Goals have no currency of their own, so they are always counted in
        // the fund's currency even when no account qualifies.
        #expect(EmergencyFundMath.currentFund(
            accounts: [foreign],
            selectedAccountIDs: [foreign.id],
            goals: [fundGoal],
            currencyCode: "USD"
        ) == 9_500)
    }
}

private var emergencyFundCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func emergencyFundDate(year: Int, month: Int, day: Int) -> Date {
    emergencyFundCalendar.date(from: DateComponents(year: year, month: month, day: day))
        ?? Date(timeIntervalSince1970: 0)
}
