import Foundation
import Testing
import VittoraCore
@testable import Vittora

@MainActor
@Suite("Emergency Fund Use Case")
struct EmergencyFundUseCaseTests {
    private let today = emergencyFundUseCaseDate(year: 2026, month: 7, day: 21)

    @Test("production wiring prioritizes recurring needs and sums selected sources")
    func recurringWiring() async throws {
        let fixture = try await makeFixture()
        await fixture.recurring.seed(RecurringRuleEntity(
            frequency: .monthly,
            nextDate: today,
            templateAmount: 1_850,
            templateCategoryID: fixture.needs.id
        ))
        try await fixture.transactions.create(TransactionEntity(
            amount: 99_999,
            date: today,
            type: .expense,
            categoryID: fixture.needs.id
        ))
        let selected = AccountEntity(
            name: "Savings",
            type: .bank,
            balance: 4_200,
            currencyCode: fixture.currencyCode
        )
        try await fixture.accounts.create(selected)
        await fixture.goals.seed(SavingsGoalEntity(
            name: "Emergency",
            targetAmount: 15_000,
            currentAmount: 9_500,
            isEmergencyFund: true
        ))

        let report = try await fixture.useCase.execute(selectedAccountIDs: [selected.id])
        let snapshot = try #require(report.snapshot)

        #expect(snapshot.baselineSource == .recurringRules)
        #expect(snapshot.essentialMonthly == 1_850)
        #expect(snapshot.currentFund == 13_700)
        #expect(snapshot.coverageMonths == Decimal(string: "7.4")!)
        #expect(snapshot.status == .comfortable)
    }

    @Test("production wiring falls back to available history months")
    func historyWiring() async throws {
        let fixture = try await makeFixture()
        try await fixture.transactions.create(TransactionEntity(
            amount: 300,
            date: emergencyFundUseCaseDate(year: 2026, month: 6, day: 5),
            type: .expense,
            categoryID: fixture.needs.id
        ))
        try await fixture.transactions.create(TransactionEntity(
            amount: 500,
            date: emergencyFundUseCaseDate(year: 2026, month: 7, day: 5),
            type: .expense,
            categoryID: fixture.needs.id
        ))

        let report = try await fixture.useCase.execute(selectedAccountIDs: [])
        let snapshot = try #require(report.snapshot)

        #expect(snapshot.baselineSource == .spendingHistory(monthCount: 2))
        #expect(snapshot.essentialMonthly == 400)
    }

    @Test("production wiring returns empty report when neither source exists")
    func neitherSourceWiring() async throws {
        let fixture = try await makeFixture()
        let report = try await fixture.useCase.execute(selectedAccountIDs: [])
        #expect(report.snapshot == nil)
    }

    /// Every fixture gets its own defaults suite and an explicit currency.
    ///
    /// Without this the suite reads `UserDefaults.standard` twice — once when an
    /// `AccountEntity` takes its default `currencyCode`, once when the use case resolves
    /// the fund currency — and a sibling suite running in parallel can change the answer
    /// between them. The account is then filtered out by the currency check and the fund
    /// under-reports. Same race as 3c129f0f, same fix.
    private func makeFixture() async throws -> Fixture {
        let suiteName = "test.emergencyfund.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test defaults suite")
        }
        defaults.set(fixtureCurrencyCode, forKey: AppUserDefaults.StandardKey.currencyCode)

        let recurring = MockRecurringRuleRepository()
        let categories = MockCategoryRepository()
        let transactions = MockTransactionRepository()
        let accounts = MockAccountRepository()
        let goals = MockSavingsGoalRepository()
        let needs = CategoryEntity(
            name: "Rent",
            icon: "house.fill",
            type: .expense,
            spendingBucket: .needs
        )
        let wants = CategoryEntity(
            name: "Dining",
            icon: "fork.knife",
            type: .expense,
            spendingBucket: .wants
        )
        try await categories.create(needs)
        try await categories.create(wants)

        return Fixture(
            recurring: recurring,
            transactions: transactions,
            accounts: accounts,
            goals: goals,
            needs: needs,
            useCase: EmergencyFundUseCase(
                recurringRuleRepository: recurring,
                categoryRepository: categories,
                transactionRepository: transactions,
                accountRepository: accounts,
                savingsGoalRepository: goals,
                todayProvider: { today },
                calendar: emergencyFundUseCaseCalendar,
                defaultsSuiteName: suiteName
            ),
            currencyCode: fixtureCurrencyCode
        )
    }
}

/// Pinned so the fixture never depends on the device locale or on whatever a parallel
/// suite last wrote to `.standard`.
private let fixtureCurrencyCode = "USD"

private struct Fixture {
    let currencyCode: String
    let recurring: MockRecurringRuleRepository
    let transactions: MockTransactionRepository
    let accounts: MockAccountRepository
    let goals: MockSavingsGoalRepository
    let needs: CategoryEntity
    let useCase: EmergencyFundUseCase

    init(
        recurring: MockRecurringRuleRepository,
        transactions: MockTransactionRepository,
        accounts: MockAccountRepository,
        goals: MockSavingsGoalRepository,
        needs: CategoryEntity,
        useCase: EmergencyFundUseCase,
        currencyCode: String
    ) {
        self.recurring = recurring
        self.transactions = transactions
        self.accounts = accounts
        self.goals = goals
        self.needs = needs
        self.useCase = useCase
        self.currencyCode = currencyCode
    }
}

private var emergencyFundUseCaseCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

private func emergencyFundUseCaseDate(year: Int, month: Int, day: Int) -> Date {
    emergencyFundUseCaseCalendar.date(from: DateComponents(year: year, month: month, day: day))
        ?? Date(timeIntervalSince1970: 0)
}
