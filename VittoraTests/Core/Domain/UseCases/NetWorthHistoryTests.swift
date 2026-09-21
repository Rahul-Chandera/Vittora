import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M1.7.7. History is reconstructed from transaction effects rather than recorded, so the
/// tests that matter are the ones where a naive reconstruction goes wrong: currencies that
/// must not be summed, and balances that cannot be replayed at all.
@MainActor
@Suite("Net Worth History Tests")
struct NetWorthHistoryTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
    }

    private func account(
        name: String = "Cash",
        balance: Decimal,
        currency: String = "USD",
        type: AccountType = .cash,
        archived: Bool = false
    ) -> AccountEntity {
        AccountEntity(
            name: name,
            type: type,
            balance: balance,
            currencyCode: currency,
            isArchived: archived
        )
    }

    private func expense(_ amount: Decimal, on date: Date, account: UUID) -> TransactionEntity {
        TransactionEntity(amount: amount, date: date, type: .expense, accountID: account)
    }

    private func makeUseCase(
        accounts: [AccountEntity],
        transactions: [TransactionEntity]
    ) async throws -> CalculateNetWorthHistoryUseCase {
        let accountRepository = MockAccountRepository()
        for account in accounts { try await accountRepository.create(account) }
        let transactionRepository = MockTransactionRepository()
        for transaction in transactions { try await transactionRepository.create(transaction) }
        return CalculateNetWorthHistoryUseCase(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            calendar: calendar
        )
    }

    /// The chart has to end on the number the Dashboard shows, or it reads as broken.
    /// With no transactions the series is a single point — see noTransactionsGivesTodayOnly
    /// — so this asserts the value rather than the count.
    @Test("the newest point equals today's net worth")
    func newestPointMatchesToday() async throws {
        let cash = account(balance: 1_000)
        let useCase = try await makeUseCase(
            accounts: [cash],
            transactions: [expense(50, on: date(2026, 4, 10), account: cash.id)]
        )

        let history = try await useCase.execute(months: 3, now: date(2026, 6, 15))

        #expect(history.points.isEmpty == false)
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 1_000)
    }

    /// The whole point of deriving: spending since a past date must raise what the balance
    /// was back then.
    @Test("a later expense is undone when walking backwards")
    func pastBalanceExcludesLaterSpending() async throws {
        let cash = account(balance: 800)
        let useCase = try await makeUseCase(
            accounts: [cash],
            transactions: [expense(200, on: date(2026, 6, 10), account: cash.id)]
        )

        let history = try await useCase.execute(months: 2, now: date(2026, 6, 15))

        // May's close predates the June expense, so the balance was 1,000 then.
        #expect(history.points.first?.netWorth(inCurrency: "USD") == 1_000)
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 800)
    }

    /// The bug the point-in-time figure was fixed for: balances summed across currencies
    /// and relabelled. A single history line would reintroduce it.
    @Test("currencies get their own series and are never summed")
    func currenciesAreNeverSummed() async throws {
        let dollars = account(name: "US", balance: 100, currency: "USD")
        let rupees = account(name: "India", balance: 7_000, currency: "INR")
        let useCase = try await makeUseCase(accounts: [dollars, rupees], transactions: [])

        let history = try await useCase.execute(months: 2, now: date(2026, 6, 15))
        let latest = try #require(history.points.last)

        #expect(latest.summary.byCurrency.count == 2)
        #expect(latest.netWorth(inCurrency: "USD") == 100)
        #expect(latest.netWorth(inCurrency: "INR") == 7_000)
        #expect(latest.summary.isMultiCurrency)
        #expect(Set(history.currencyCodes) == ["USD", "INR"])
    }

    /// A legacy transfer leg has no direction, so its effect is unknowable. Reconciliation
    /// skips such accounts; drawing a line for them would be quietly wrong.
    @Test("an account touched by a directionless transfer is excluded and named")
    func nonDerivableAccountIsExcluded() async throws {
        let cash = account(name: "Cash", balance: 500)
        let legacy = TransactionEntity(
            amount: 50,
            date: date(2026, 6, 1),
            type: .transfer,
            accountID: cash.id
        )
        let useCase = try await makeUseCase(accounts: [cash], transactions: [legacy])

        let history = try await useCase.execute(months: 2, now: date(2026, 6, 15))

        #expect(history.isEmpty)
        #expect(history.nonDerivableAccountNames == ["Cash"])
    }

    @Test("a derivable account still charts when another is excluded")
    func derivableAccountSurvivesAnExclusion() async throws {
        let good = account(name: "Good", balance: 300)
        let bad = account(name: "Legacy", balance: 500)
        let legacy = TransactionEntity(
            amount: 50,
            date: date(2026, 6, 1),
            type: .transfer,
            accountID: bad.id
        )
        let useCase = try await makeUseCase(accounts: [good, bad], transactions: [legacy])

        let history = try await useCase.execute(months: 2, now: date(2026, 6, 15))

        #expect(history.nonDerivableAccountNames == ["Legacy"])
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 300)
    }

    /// The series must end on the same number the Dashboard shows, so archived accounts are
    /// excluded here exactly as CalculateNetWorthUseCase excludes them.
    @Test("archived accounts are excluded, matching the point-in-time figure")
    func archivedAccountsAreExcluded() async throws {
        let live = account(name: "Live", balance: 400)
        let old = account(name: "Old", balance: 9_000, archived: true)
        let useCase = try await makeUseCase(accounts: [live, old], transactions: [])

        let history = try await useCase.execute(months: 2, now: date(2026, 6, 15))
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 400)
    }

    @Test("a credit card reduces net worth rather than adding to it")
    func liabilitiesSubtract() async throws {
        let cash = account(name: "Cash", balance: 1_000)
        let card = account(name: "Card", balance: 400, type: .creditCard)
        let useCase = try await makeUseCase(accounts: [cash, card], transactions: [])

        let history = try await useCase.execute(months: 1, now: date(2026, 6, 15))
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 600)
    }

    @Test("no accounts means no series, not a row of zeroes")
    func noAccountsMeansNoSeries() async throws {
        let useCase = try await makeUseCase(accounts: [], transactions: [])
        #expect(try await useCase.execute(months: 6, now: date(2026, 6, 15)).isEmpty)
    }

    @Test("a non-positive month count is refused rather than looping")
    func nonPositiveMonthsIsEmpty() async throws {
        let useCase = try await makeUseCase(accounts: [account(balance: 10)], transactions: [])
        #expect(try await useCase.execute(months: 0, now: date(2026, 6, 15)).isEmpty)
    }

    @Test("points run oldest first, so a chart reads left to right")
    func pointsAreChronological() async throws {
        let useCase = try await makeUseCase(accounts: [account(balance: 10)], transactions: [])
        let history = try await useCase.execute(months: 5, now: date(2026, 6, 15))
        #expect(history.points.map(\.date) == history.points.map(\.date).sorted())
    }

    /// With nothing left to undo, every earlier point reconstructs to the same balance and
    /// the chart shows a flat line implying net worth held steady — when there is simply no
    /// record of that period. Found by looking at the rendered chart, not by a test.
    @Test("the pre-ledger flat run is trimmed to a single anchor point")
    func preLedgerFlatRunIsTrimmed() async throws {
        let cash = account(balance: 900)
        let useCase = try await makeUseCase(
            accounts: [cash],
            transactions: [expense(100, on: date(2026, 5, 20), account: cash.id)]
        )

        let history = try await useCase.execute(months: 12, now: date(2026, 6, 15))

        // April (the anchor), May, June — not a year of invented flat points.
        #expect(history.points.count == 3)
        // The anchor and May both predate nothing, so they hold the opening balance.
        #expect(history.points.first?.netWorth(inCurrency: "USD") == 1_000)
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 900)
    }

    /// A month with no activity after the ledger starts really was flat, so repeats on
    /// that side are kept — only the pre-ledger run is trimmed.
    @Test("a quiet month after the first transaction is still charted")
    func quietMonthAfterLedgerStartIsKept() async throws {
        let cash = account(balance: 700)
        let useCase = try await makeUseCase(
            accounts: [cash],
            transactions: [expense(300, on: date(2026, 4, 5), account: cash.id)]
        )

        let history = try await useCase.execute(months: 12, now: date(2026, 6, 15))

        // March anchor, then April, May, June — May is quiet but still drawn.
        #expect(history.points.count == 4)
        #expect(history.points.last?.netWorth(inCurrency: "USD") == 700)
    }

    /// An empty ledger still gets today's point, so the report is not blank for a user who
    /// has accounts but has not recorded anything yet.
    @Test("with no transactions at all, only today is charted")
    func noTransactionsGivesTodayOnly() async throws {
        let useCase = try await makeUseCase(accounts: [account(balance: 50)], transactions: [])
        let history = try await useCase.execute(months: 12, now: date(2026, 6, 15))
        #expect(history.points.count == 1)
    }
}
