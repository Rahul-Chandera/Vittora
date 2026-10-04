import Foundation
import VittoraCore

/// Net worth at a past point in time.
struct NetWorthHistoryPoint: Sendable, Equatable, Identifiable {
    /// End of the period this point measures.
    let date: Date
    let summary: NetWorthSummary

    var id: Date { date }

    func netWorth(inCurrency code: String) -> Decimal? {
        summary.byCurrency.first { $0.currencyCode == code }?.netWorth
    }
}

struct NetWorthHistory: Sendable, Equatable {
    /// Oldest first, so a chart reads left to right.
    let points: [NetWorthHistoryPoint]
    /// Accounts whose past balance cannot be reconstructed, named so the UI can say why
    /// the series excludes them rather than drawing a line that is quietly wrong.
    let nonDerivableAccountNames: [String]

    var isEmpty: Bool { points.isEmpty }

    /// Currencies present across the whole series, ordered by the latest point's ranking.
    var currencyCodes: [String] {
        guard let latest = points.last else { return [] }
        return latest.summary.byCurrency.map(\.currencyCode)
    }
}

/// Net worth over time (M1.7.7), reconstructed rather than recorded.
///
/// No new model and no migration: a past balance is the current balance minus every
/// transaction effect dated after that point, which is the same replay
/// `ReconcileAccountBalanceUseCase` already trusts for drift detection.
///
/// **Per currency, never summed across them.** The point-in-time figure learned this the
/// hard way — a ₹72,15,490 account was reported as "$72,15,490.00" because balances were
/// totalled and then labelled with the display currency, overstating net worth by the
/// whole FX factor (owner decision, 2026-08-16). A single history line would reintroduce
/// exactly that, so each currency gets its own series.
struct CalculateNetWorthHistoryUseCase: Sendable {
    let accountRepository: any AccountRepository
    let transactionRepository: any TransactionRepository
    let calendar: Calendar

    nonisolated init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository,
        calendar: Calendar = .current
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.calendar = calendar
    }

    /// `months` points ending at `now`, oldest first.
    func execute(months: Int = 12, now: Date = .now) async throws -> NetWorthHistory {
        guard months > 0 else { return NetWorthHistory(points: [], nonDerivableAccountNames: []) }

        // Archived accounts are excluded, matching CalculateNetWorthUseCase. The series has
        // to end on the same number the Dashboard shows, or the chart reads as broken.
        let accounts = try await accountRepository.fetchAll().filter { !$0.isArchived }
        guard !accounts.isEmpty else {
            return NetWorthHistory(points: [], nonDerivableAccountNames: [])
        }

        // Uncapped, like reconciliation: replaying the first 500 rows would silently
        // truncate history for anyone with a real ledger.
        let transactions = try await transactionRepository.fetchAllForReconciliation()

        // A legacy transfer leg carries no direction, so its effect on its own account is
        // unknowable — signedBalanceEffect returns 0 for it. Reconciliation skips such
        // accounts rather than guess, and so does this: a line drawn from a balance that
        // cannot be reconstructed is worse than no line.
        let nonDerivableAccountIDs = Set(
            transactions
                .filter { $0.type == .transfer && $0.transferDirection == nil }
                .compactMap(\.accountID)
        )
        let derivable = accounts.filter { !nonDerivableAccountIDs.contains($0.id) }
        let excludedNames = accounts
            .filter { nonDerivableAccountIDs.contains($0.id) }
            .map(\.name)
            .sorted()

        guard !derivable.isEmpty else {
            return NetWorthHistory(points: [], nonDerivableAccountNames: excludedNames)
        }

        let derivableIDs = Set(derivable.map(\.id))
        let relevant = transactions.filter { $0.accountID.map(derivableIDs.contains) ?? false }

        // Trim the run of points that predate the ledger. With nothing left to undo, the
        // reconstruction returns the same balance over and over, and the chart shows a flat
        // line implying net worth held steady when in truth no record of that period
        // exists. One point is kept immediately before the first transaction, as an anchor
        // the opening balance can be read from; the rest are dropped.
        //
        // Points after the first transaction are NOT trimmed even when they repeat: a
        // month with no activity really was flat, and that is worth showing.
        let candidateDates = stride(from: months - 1, through: 0, by: -1)
            .compactMap { Self.periodEnd(monthsBefore: $0, from: now, calendar: calendar) }
        let startIndex: Int
        if let earliest = relevant.map(\.date).min(),
           let firstCovering = candidateDates.firstIndex(where: { $0 >= earliest }) {
            startIndex = max(0, firstCovering - 1)
        } else {
            // No transactions at all: one point, not a year of invented flat ones.
            startIndex = max(0, candidateDates.count - 1)
        }

        var points: [NetWorthHistoryPoint] = []
        for pointDate in candidateDates[startIndex...] {

            // Effects after this instant are undone to walk the balance backwards.
            var reversals: [UUID: Decimal] = [:]
            for transaction in relevant where transaction.date > pointDate {
                guard let accountID = transaction.accountID else { continue }
                reversals[accountID, default: 0] += transaction.signedBalanceEffect
            }

            let historical = derivable.map { account in
                var copy = account
                copy.balance = account.balance - (reversals[account.id] ?? 0)
                return copy
            }
            points.append(
                NetWorthHistoryPoint(
                    date: pointDate,
                    summary: NetWorthSummary.build(from: historical)
                )
            )
        }

        return NetWorthHistory(points: points, nonDerivableAccountNames: excludedNames)
    }

    /// End of the month `monthsBefore` ago — except for the newest point, which is `now`
    /// so the series ends on today's actual net worth rather than last month's close.
    nonisolated static func periodEnd(monthsBefore offset: Int, from now: Date, calendar: Calendar) -> Date? {
        guard offset > 0 else { return now }
        guard let shifted = calendar.date(byAdding: .month, value: -offset, to: now),
              let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: shifted)
              ),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return nil }
        // Last instant of that month, so a transaction dated on the final day counts.
        return nextMonth.addingTimeInterval(-1)
    }
}
