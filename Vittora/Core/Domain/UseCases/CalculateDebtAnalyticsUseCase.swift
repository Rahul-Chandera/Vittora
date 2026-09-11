import Foundation
import VittoraCore

// App target defaults to MainActor isolation; these analytics types must stay
// callable from pure/nonisolated analyse paths and tests.
nonisolated enum DebtAgeBucket: String, CaseIterable, Sendable, Identifiable {
    case upTo30, days31To60, days61To90, over90

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upTo30: return String(localized: "0-30 days")
        case .days31To60: return String(localized: "31-60 days")
        case .days61To90: return String(localized: "61-90 days")
        case .over90: return String(localized: "90+ days")
        }
    }

    static func bucket(forDays days: Int) -> DebtAgeBucket {
        let clamped = max(0, days)
        switch clamped {
        case ...30: return .upTo30
        case 31...60: return .days31To60
        case 61...90: return .days61To90
        default: return .over90
        }
    }
}

nonisolated struct DebtAgingBucket: Sendable, Identifiable, Equatable {
    let bucket: DebtAgeBucket
    let count: Int
    let owedToMe: Decimal
    let iOwe: Decimal
    var id: String { bucket.rawValue }
}

nonisolated struct CounterpartyExposure: Sendable, Identifiable, Equatable {
    let payeeID: UUID
    let payeeName: String
    let owedToMe: Decimal
    let iOwe: Decimal
    let oldestOutstandingDays: Int
    let overdueCount: Int
    let settlementVelocity: SettlementVelocity?
    var id: UUID { payeeID }
    var net: Decimal { owedToMe - iOwe }
}

nonisolated struct SettlementVelocity: Sendable, Equatable {
    let medianDays: Int
    let sampleSize: Int
}

nonisolated struct DebtOverdueRisk: Sendable, Equatable {
    let count: Int
    let totalRemaining: Decimal
    let maxDaysOverdue: Int
    let dueWithin7DaysCount: Int
}

// ponytail: DebtEntry carries no currency code — every amount here is in the single app display currency; per-currency subtotalling is impossible without a schema change.
nonisolated struct DebtAnalytics: Sendable, Equatable {
    let aging: [DebtAgingBucket]
    let exposures: [CounterpartyExposure]
    let concentrationShare: Decimal?
    let concentrationPayeeName: String?
    let velocity: SettlementVelocity?
    let settledSampleSize: Int
    let overdue: DebtOverdueRisk

    static let minimumVelocitySample = 3

    var hasData: Bool { !exposures.isEmpty || settledSampleSize > 0 }
}

nonisolated struct CalculateDebtAnalyticsUseCase: Sendable {
    let fetchLedgerUseCase: FetchDebtLedgerUseCase
    let fetchOverdueUseCase: FetchOverdueDebtsUseCase
    let debtRepository: any DebtRepository

    func execute(now: Date = .now) async throws -> DebtAnalytics {
        async let ledgerTask = fetchLedgerUseCase.execute()
        async let overdueTask = fetchOverdueUseCase.execute()
        async let allTask = debtRepository.fetchAll()
        let (ledger, overdue, all) = try await (ledgerTask, overdueTask, allTask)
        let settled = all.filter(\.isSettled)
        return Self.analyse(ledger: ledger, settled: settled, overdue: overdue, now: now)
    }

    static func analyse(
        ledger: [DebtLedgerEntry],
        settled: [DebtEntry],
        overdue: [DebtEntry],
        now: Date
    ) -> DebtAnalytics {
        let outstanding = ledger.flatMap(\.entries)

        let aging = buildAging(outstanding: outstanding, now: now)
        let exposures = buildExposures(ledger: ledger, settled: settled, overdue: overdue, now: now)

        let totalOwedToMe = exposures.reduce(Decimal(0)) { $0 + $1.owedToMe }
        let concentrationShare: Decimal?
        let concentrationPayeeName: String?
        if totalOwedToMe == 0 {
            concentrationShare = nil
            concentrationPayeeName = nil
        } else if let top = exposures.max(by: { $0.owedToMe < $1.owedToMe }) {
            concentrationShare = top.owedToMe / totalOwedToMe
            concentrationPayeeName = top.payeeName
        } else {
            concentrationShare = nil
            concentrationPayeeName = nil
        }

        let settledSampleSize = settled.count
        let velocity: SettlementVelocity?
        if settledSampleSize >= DebtAnalytics.minimumVelocitySample {
            let days = settled.map { daysBetween(from: $0.createdAt, to: $0.updatedAt) }
            velocity = SettlementVelocity(
                medianDays: median(of: days),
                sampleSize: settledSampleSize
            )
        } else {
            velocity = nil
        }

        let overdueRisk = buildOverdueRisk(outstanding: outstanding, overdue: overdue, now: now)

        return DebtAnalytics(
            aging: aging,
            exposures: exposures,
            concentrationShare: concentrationShare,
            concentrationPayeeName: concentrationPayeeName,
            velocity: velocity,
            settledSampleSize: settledSampleSize,
            overdue: overdueRisk
        )
    }

    // MARK: - Private

    private static func buildAging(
        outstanding: [DebtEntry],
        now: Date
    ) -> [DebtAgingBucket] {
        var counts: [DebtAgeBucket: Int] = [:]
        var owedToMe: [DebtAgeBucket: Decimal] = [:]
        var iOwe: [DebtAgeBucket: Decimal] = [:]

        for entry in outstanding {
            let bucket = DebtAgeBucket.bucket(forDays: daysBetween(from: entry.createdAt, to: now))
            counts[bucket, default: 0] += 1
            if entry.direction == .lent {
                owedToMe[bucket, default: 0] += entry.remainingAmount
            } else {
                iOwe[bucket, default: 0] += entry.remainingAmount
            }
        }

        return DebtAgeBucket.allCases.compactMap { bucket in
            let count = counts[bucket, default: 0]
            guard count > 0 else { return nil }
            return DebtAgingBucket(
                bucket: bucket,
                count: count,
                owedToMe: owedToMe[bucket, default: 0],
                iOwe: iOwe[bucket, default: 0]
            )
        }
    }

    private static func buildExposures(
        ledger: [DebtLedgerEntry],
        settled: [DebtEntry],
        overdue: [DebtEntry],
        now: Date
    ) -> [CounterpartyExposure] {
        let overdueCountByPayee = Dictionary(grouping: overdue, by: \.payeeID).mapValues(\.count)
        let settledByPayee = Dictionary(grouping: settled, by: \.payeeID)

        return ledger.map { group in
            var owedToMe = Decimal(0)
            var iOwe = Decimal(0)
            var oldest = 0
            for entry in group.entries {
                if entry.direction == .lent {
                    owedToMe += entry.remainingAmount
                } else {
                    iOwe += entry.remainingAmount
                }
                oldest = max(oldest, daysBetween(from: entry.createdAt, to: now))
            }
            let settledDays = settledByPayee[group.payee.id, default: []].map {
                daysBetween(from: $0.createdAt, to: $0.updatedAt)
            }
            let settlementVelocity: SettlementVelocity?
            if settledDays.count >= DebtAnalytics.minimumVelocitySample {
                settlementVelocity = SettlementVelocity(
                    medianDays: median(of: settledDays),
                    sampleSize: settledDays.count
                )
            } else {
                settlementVelocity = nil
            }
            return CounterpartyExposure(
                payeeID: group.payee.id,
                payeeName: group.payee.name,
                owedToMe: owedToMe,
                iOwe: iOwe,
                oldestOutstandingDays: oldest,
                overdueCount: overdueCountByPayee[group.payee.id, default: 0],
                settlementVelocity: settlementVelocity
            )
        }
        .sorted { lhs, rhs in
            let absLHS = abs(lhs.net)
            let absRHS = abs(rhs.net)
            if absLHS != absRHS { return absLHS > absRHS }
            return lhs.payeeName < rhs.payeeName
        }
    }

    private static func buildOverdueRisk(
        outstanding: [DebtEntry],
        overdue: [DebtEntry],
        now: Date
    ) -> DebtOverdueRisk {
        let totalRemaining = overdue.reduce(Decimal(0)) { $0 + $1.remainingAmount }
        let maxDaysOverdue = overdue.map { entry -> Int in
            guard let due = entry.dueDate else { return 0 }
            return daysBetween(from: due, to: now)
        }.max() ?? 0

        let windowEnd = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let dueWithin7DaysCount = outstanding.filter { entry in
            guard let due = entry.dueDate else { return false }
            return due >= now && due < windowEnd
        }.count

        return DebtOverdueRisk(
            count: overdue.count,
            totalRemaining: totalRemaining,
            maxDaysOverdue: maxDaysOverdue,
            dueWithin7DaysCount: dueWithin7DaysCount
        )
    }

    private static func daysBetween(from start: Date, to end: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days)
    }

    private static func median(of values: [Int]) -> Int {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        }
        let a = sorted[count / 2 - 1]
        let b = sorted[count / 2]
        return (a + b) / 2
    }
}
