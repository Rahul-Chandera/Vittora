import Foundation
import VittoraCore

/// Balances totalled per currency, never across them.
///
/// Accounts carry their own `currencyCode` and the app has no exchange rates.
/// Summing an INR balance into a total then labelling it with the display
/// currency does not convert anything — it relabels. A ₹72,15,490 account was
/// reported as "$72,15,490.00" on the Dashboard, the Accounts screen and the
/// Net Worth report, overstating net worth by the whole FX factor.
///
/// Owner decision (2026-08-16): subtotal per currency rather than convert. A
/// single-currency ledger — which is nearly everyone — reads exactly as before,
/// but now labelled with the currency the money is actually in.
struct NetWorthSummary: Sendable, Equatable {
    struct CurrencyTotals: Sendable, Equatable, Identifiable {
        let currencyCode: String
        let assets: Decimal
        /// The amount OWED, as a positive number — not the raw account balance.
        ///
        /// A liability account's balance is `opening + Σ transaction effects`,
        /// and spending on a card decrements it, so the stored balance is
        /// negative. `build` negates it here; see the note there.
        let liabilities: Decimal

        var netWorth: Decimal { assets - liabilities }
        var id: String { currencyCode }
    }

    /// One entry per currency present, ordered by net worth descending so the
    /// dominant currency leads. Empty when there are no accounts.
    let byCurrency: [CurrencyTotals]

    var isMultiCurrency: Bool { byCurrency.count > 1 }

    /// The only currency in play, or nil when there are none or several.
    /// Callers that show a single figure must use this and fall back to the
    /// per-currency list — there is no meaningful cross-currency total.
    var singleCurrency: CurrencyTotals? {
        byCurrency.count == 1 ? byCurrency[0] : nil
    }

    static func build(from accounts: [AccountEntity]) -> NetWorthSummary {
        var assets: [String: Decimal] = [:]
        var liabilities: [String: Decimal] = [:]

        for account in accounts {
            let code = account.currencyCode
            if account.type.isAsset {
                assets[code, default: 0] += account.balance
            } else {
                // Negated, because a liability's balance is NEGATIVE. It is
                // `opening + Σ transaction effects` and an expense on a card
                // decrements it, so a card owing 1,266.97 stores -1,266.97 —
                // SyncIntegrityValidator only flags a negative balance on an
                // *asset* for exactly this reason.
                //
                // Adding it raw made `netWorth` subtract a negative: assets of
                // 13,124.95 against a card owing 1,266.97 reported 14,391.92
                // instead of 11,857.98, on the Dashboard, the Accounts screen
                // and the Net Worth report. The composition bar was wrong the
                // same way — its asset fraction exceeded 1, so the liability
                // segment never drew.
                //
                // An overpaid card has a positive balance and correctly becomes
                // a negative liability, i.e. it adds to net worth.
                liabilities[code, default: 0] -= account.balance
            }
        }

        let codes: Set<String> = Set(assets.keys).union(liabilities.keys)
        var totals: [CurrencyTotals] = []
        for code in codes {
            let asset: Decimal = assets[code] ?? 0
            let liability: Decimal = liabilities[code] ?? 0
            totals.append(
                CurrencyTotals(currencyCode: code, assets: asset, liabilities: liability)
            )
        }

        // Deterministic order: biggest position first, then by code so equal
        // positions do not reshuffle between launches. Written out rather than
        // chained onto the map — the one-expression version tripped the type
        // checker's time limit.
        totals.sort { lhs, rhs in
            if lhs.netWorth == rhs.netWorth {
                return lhs.currencyCode < rhs.currencyCode
            }
            return lhs.netWorth > rhs.netWorth
        }

        return NetWorthSummary(byCurrency: totals)
    }
}

struct CalculateNetWorthUseCase: Sendable {
    let accountRepository: any AccountRepository

    nonisolated init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    func execute() async throws -> NetWorthSummary {
        let accounts = try await accountRepository.fetchAll()
            .filter { !$0.isArchived }
        return NetWorthSummary.build(from: accounts)
    }
}
