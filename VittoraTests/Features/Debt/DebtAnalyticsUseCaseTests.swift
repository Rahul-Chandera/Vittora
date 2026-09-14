import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Debt Analytics Use Case Tests")
struct DebtAnalyticsUseCaseTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Helpers

    private func daysAgo(_ days: Int) throws -> Date {
        try #require(Calendar.current.date(byAdding: .day, value: -days, to: now))
    }

    private func daysFromNow(_ days: Int) throws -> Date {
        try #require(Calendar.current.date(byAdding: .day, value: days, to: now))
    }

    private func debt(
        payeeID: UUID,
        amount: Decimal,
        settledAmount: Decimal = 0,
        direction: DebtDirection,
        dueDate: Date? = nil,
        isSettled: Bool = false,
        createdAt: Date,
        updatedAt: Date? = nil
    ) -> DebtEntry {
        DebtEntry(
            payeeID: payeeID,
            amount: amount,
            settledAmount: settledAmount,
            direction: direction,
            dueDate: dueDate,
            isSettled: isSettled,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }

    private func ledger(payee: PayeeEntity, entries: [DebtEntry]) -> DebtLedgerEntry {
        var totalLent = Decimal(0)
        var totalBorrowed = Decimal(0)
        for entry in entries {
            if entry.direction == .lent {
                totalLent += entry.remainingAmount
            } else {
                totalBorrowed += entry.remainingAmount
            }
        }
        return DebtLedgerEntry(
            payee: payee,
            entries: entries,
            totalLent: totalLent,
            totalBorrowed: totalBorrowed
        )
    }

    // MARK: - Aging

    @Test("aging buckets at 30/31/60/61/90/91-day edges; empty buckets omitted")
    func agingBucketEdges() throws {
        let payee = PayeeEntity(name: "Edge")
        let entries = try [
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(30)),
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(31)),
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(60)),
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(61)),
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(90)),
            debt(payeeID: payee.id, amount: 10, direction: .lent, createdAt: daysAgo(91)),
        ]

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [ledger(payee: payee, entries: entries)],
            settled: [],
            overdue: [],
            now: now
        )

        #expect(result.aging.map(\.bucket) == DebtAgeBucket.allCases)
        #expect(result.aging.map(\.count) == [1, 2, 2, 1])

        // Only upTo30 + over90 → middle buckets omitted
        let sparse = try [
            debt(payeeID: payee.id, amount: 1, direction: .lent, createdAt: daysAgo(0)),
            debt(payeeID: payee.id, amount: 1, direction: .lent, createdAt: daysAgo(91)),
        ]
        let sparseResult = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [ledger(payee: payee, entries: sparse)],
            settled: [],
            overdue: [],
            now: now
        )
        #expect(sparseResult.aging.map(\.bucket) == [.upTo30, .over90])
    }

    @Test("aging sums lent and borrowed remaining amounts separately")
    func agingSumsLentAndBorrowed() throws {
        let payee = PayeeEntity(name: "Sums")
        let lent = Decimal(string: "100.50") ?? 0
        let borrowed = Decimal(string: "40.25") ?? 0
        let entries = try [
            debt(
                payeeID: payee.id,
                amount: lent,
                settledAmount: Decimal(string: "10.00") ?? 0,
                direction: .lent,
                createdAt: daysAgo(10)
            ),
            debt(
                payeeID: payee.id,
                amount: borrowed,
                direction: .borrowed,
                createdAt: daysAgo(15)
            ),
        ]

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [ledger(payee: payee, entries: entries)],
            settled: [],
            overdue: [],
            now: now
        )

        #expect(result.aging.count == 1)
        #expect(result.aging[0].bucket == .upTo30)
        #expect(result.aging[0].owedToMe == (Decimal(string: "90.50") ?? 0))
        #expect(result.aging[0].iOwe == borrowed)
        #expect(result.aging[0].count == 2)
    }

    // MARK: - Exposures & concentration

    @Test("exposures ordered by abs(net); concentration share for dominant counterparty")
    func exposureOrderingAndConcentration() throws {
        let alice = PayeeEntity(name: "Alice")
        let bob = PayeeEntity(name: "Bob")
        let cara = PayeeEntity(name: "Cara")

        let aliceEntries = try [
            debt(payeeID: alice.id, amount: Decimal(string: "750") ?? 0, direction: .lent, createdAt: daysAgo(5)),
        ]
        let bobEntries = try [
            debt(payeeID: bob.id, amount: Decimal(string: "250") ?? 0, direction: .lent, createdAt: daysAgo(5)),
        ]
        // Larger abs(net) via borrowed than Bob's lent
        let caraEntries = try [
            debt(payeeID: cara.id, amount: Decimal(string: "400") ?? 0, direction: .borrowed, createdAt: daysAgo(5)),
        ]

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [
                ledger(payee: alice, entries: aliceEntries),
                ledger(payee: bob, entries: bobEntries),
                ledger(payee: cara, entries: caraEntries),
            ],
            settled: [],
            overdue: [],
            now: now
        )

        #expect(result.exposures.map(\.payeeName) == ["Alice", "Cara", "Bob"])
        #expect(result.concentrationShare == (Decimal(string: "0.75") ?? 0))
        #expect(result.concentrationPayeeName == "Alice")
    }

    @Test("concentrationShare is nil when nothing is owed to the user")
    func concentrationNilWhenNothingOwedToUser() throws {
        let payee = PayeeEntity(name: "OnlyBorrow")
        let entries = try [
            debt(payeeID: payee.id, amount: 100, direction: .borrowed, createdAt: daysAgo(3)),
        ]

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [ledger(payee: payee, entries: entries)],
            settled: [],
            overdue: [],
            now: now
        )

        #expect(result.concentrationShare == nil)
        #expect(result.concentrationPayeeName == nil)
    }

    // MARK: - Settlement velocity

    @Test("velocity nil with 2 settled; median present with 3 (not mean)")
    func settlementVelocityMedian() throws {
        let payeeID = UUID()

        let two = try [
            debt(
                payeeID: payeeID,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(10),
                updatedAt: daysAgo(8)
            ),
            debt(
                payeeID: payeeID,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(20),
                updatedAt: daysAgo(16)
            ),
        ]
        let twoResult = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [],
            settled: two,
            overdue: [],
            now: now
        )
        #expect(twoResult.velocity == nil)
        #expect(twoResult.settledSampleSize == 2)
        #expect(twoResult.hasData == true)

        // Days to settle: 2, 4, 30 → mean 12, median 4
        let three = try [
            debt(
                payeeID: payeeID,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(10),
                updatedAt: daysAgo(8)
            ),
            debt(
                payeeID: payeeID,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(20),
                updatedAt: daysAgo(16)
            ),
            debt(
                payeeID: payeeID,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(40),
                updatedAt: daysAgo(10)
            ),
        ]
        let threeResult = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [],
            settled: three,
            overdue: [],
            now: now
        )
        #expect(threeResult.settledSampleSize == 3)
        #expect(threeResult.velocity?.sampleSize == 3)
        #expect(threeResult.velocity?.medianDays == 4)
    }

    @Test("per-counterparty velocity nil with 2 settled; median 4 with 3 (days 2, 4, 30)")
    func perCounterpartySettlementVelocity() throws {
        let alice = PayeeEntity(name: "Alice")
        let bob = PayeeEntity(name: "Bob")

        let aliceOutstanding = try [
            debt(payeeID: alice.id, amount: 50, direction: .lent, createdAt: daysAgo(5)),
        ]
        let bobOutstanding = try [
            debt(payeeID: bob.id, amount: 50, direction: .lent, createdAt: daysAgo(5)),
        ]

        let aliceSettled = try [
            debt(
                payeeID: alice.id,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(10),
                updatedAt: daysAgo(8)
            ),
            debt(
                payeeID: alice.id,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(20),
                updatedAt: daysAgo(16)
            ),
        ]
        // Days to settle: 2, 4, 30 → median 4
        let bobSettled = try [
            debt(
                payeeID: bob.id,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(10),
                updatedAt: daysAgo(8)
            ),
            debt(
                payeeID: bob.id,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(20),
                updatedAt: daysAgo(16)
            ),
            debt(
                payeeID: bob.id,
                amount: 10,
                direction: .lent,
                isSettled: true,
                createdAt: daysAgo(40),
                updatedAt: daysAgo(10)
            ),
        ]

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [
                ledger(payee: alice, entries: aliceOutstanding),
                ledger(payee: bob, entries: bobOutstanding),
            ],
            settled: aliceSettled + bobSettled,
            overdue: [],
            now: now
        )

        // #require, not optional chaining: a nil exposure would make an
        // `== nil` assertion pass without the code under test ever running.
        let aliceExposure = try #require(result.exposures.first { $0.payeeID == alice.id })
        let bobExposure = try #require(result.exposures.first { $0.payeeID == bob.id })
        #expect(aliceExposure.settlementVelocity == nil)
        let bobVelocity = try #require(bobExposure.settlementVelocity)
        #expect(bobVelocity.medianDays == 4)
        #expect(bobVelocity.sampleSize == 3)
    }

    // MARK: - Overdue risk

    @Test("overdue risk: count, remaining, max days, due within 7 days")
    func overdueRisk() throws {
        let payee = PayeeEntity(name: "Risk")
        let overdueEntry = try debt(
            payeeID: payee.id,
            amount: Decimal(string: "200.00") ?? 0,
            settledAmount: Decimal(string: "50.00") ?? 0,
            direction: .lent,
            dueDate: daysAgo(12),
            createdAt: daysAgo(40)
        )
        let dueSoon = try debt(
            payeeID: payee.id,
            amount: Decimal(string: "80.00") ?? 0,
            direction: .borrowed,
            dueDate: daysFromNow(3),
            createdAt: daysAgo(5)
        )
        let dueLater = try debt(
            payeeID: payee.id,
            amount: 20,
            direction: .lent,
            dueDate: daysFromNow(10),
            createdAt: daysAgo(2)
        )

        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [ledger(payee: payee, entries: [overdueEntry, dueSoon, dueLater])],
            settled: [],
            overdue: [overdueEntry],
            now: now
        )

        #expect(result.overdue.count == 1)
        #expect(result.overdue.totalRemaining == (Decimal(string: "150.00") ?? 0))
        #expect(result.overdue.maxDaysOverdue == 12)
        #expect(result.overdue.dueWithin7DaysCount == 1)
        #expect(result.exposures.first?.overdueCount == 1)
        #expect(result.exposures.first?.oldestOutstandingDays == 40)
    }

    // MARK: - Empty

    @Test("fully empty input yields hasData false and zeroed risk")
    func emptyInput() {
        let result = CalculateDebtAnalyticsUseCase.analyse(
            ledger: [],
            settled: [],
            overdue: [],
            now: now
        )

        #expect(result.hasData == false)
        #expect(result.aging.isEmpty)
        #expect(result.exposures.isEmpty)
        #expect(result.velocity == nil)
        #expect(result.settledSampleSize == 0)
        #expect(result.concentrationShare == nil)
        #expect(result.overdue.count == 0)
        #expect(result.overdue.totalRemaining == 0)
        #expect(result.overdue.maxDaysOverdue == 0)
        #expect(result.overdue.dueWithin7DaysCount == 0)
    }
}
