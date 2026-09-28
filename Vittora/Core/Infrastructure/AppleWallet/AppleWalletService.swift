#if os(iOS)
import FinanceKit
import Foundation
import OSLog
import UIKit

/// The only code that talks to FinanceKit (M3.7.1).
///
/// Two gates stand in front of every `FinanceStore` call, and there is no path
/// around `guardedStore()`:
///
/// 1. `isEntitled` — the `VittoraFinanceKitEnabled` Info.plist flag. Without
///    the managed `com.apple.developer.financekit` entitlement, FinanceKit
///    does not fail: it traps. `isDataAvailable(.financialData)` still returns
///    true (it does on the iOS 26.2 simulator), and the first `FinanceStore`
///    call then hits an assertion inside FinanceKit and kills the app. iOS has
///    no public API to read the process's own entitlements, so the flag is set
///    by hand together with the entitlement; `AppleWalletEntitlementTests`
///    fails if the two ever disagree.
/// 2. `isDataAvailable(.financialData)` — Apple terminates apps that query
///    financial data it has said is unavailable (iPad, unsupported regions).
@MainActor
@Observable
final class AppleWalletService {
    static let shared = AppleWalletService()

    private static let logger = Logger(subsystem: "com.vittora.app", category: "apple-wallet")
    private static let autoImportKey = "appleWallet.autoImportEnabledAt"
    private static let linksKey = "appleWallet.accountLinks"
    private static let tokenKeyPrefix = "appleWallet.historyToken."

    enum Availability: Equatable {
        case checking
        /// FinanceKit's financial data is iPhone-only.
        case needsiPhone
        /// No entitlement, unsupported region, or no Wallet financial data.
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    private(set) var availability: Availability = .checking
    private let defaults = UserDefaults.standard

    private init() {}

    /// Set only when the build carries the FinanceKit entitlement.
    nonisolated static var isEntitled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "VittoraFinanceKitEnabled") as? Bool == true
    }

    /// UI tests only: renders a state without touching FinanceKit, so the
    /// explanation screens have coverage on a simulator.
    nonisolated static var forcedState: Availability? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--uitesting"),
              let raw = args.first(where: { $0.hasPrefix("--ui-test-apple-wallet-state=") })?
                .split(separator: "=").last
        else { return nil }
        switch raw {
        case "unavailable": return .unavailable
        case "denied": return .denied
        case "needs-iphone": return .needsiPhone
        default: return nil
        }
    }

    /// No menu entry until the entitlement is in — an import nobody can use is
    /// a dead end, not a feature.
    nonisolated static var isEntryVisible: Bool { isEntitled || forcedState != nil }

    // MARK: - Availability and consent

    func refreshAvailability() async {
        if let forced = Self.forcedState {
            availability = forced
            return
        }
        guard Self.isEntitled else {
            availability = .unavailable
            return
        }
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            availability = .needsiPhone
            return
        }
        guard let store = guardedStore() else {
            availability = .unavailable
            return
        }
        do {
            availability = Self.availability(for: try await store.authorizationStatus())
        } catch {
            Self.logger.error("FinanceKit status failed: \(error.localizedDescription, privacy: .public)")
            availability = .unavailable
        }
    }

    func requestAuthorization() async {
        guard let store = guardedStore() else {
            availability = .unavailable
            return
        }
        do {
            availability = Self.availability(for: try await store.requestAuthorization())
        } catch {
            Self.logger.error("FinanceKit authorization failed: \(error.localizedDescription, privacy: .public)")
            availability = .unavailable
        }
    }

    /// Nil unless both gates pass — the single way to reach FinanceKit.
    private func guardedStore() -> FinanceStore? {
        guard Self.isEntitled, Self.forcedState == nil,
              FinanceStore.isDataAvailable(.financialData) else { return nil }
        return FinanceStore.shared
    }

    private static func availability(for status: AuthorizationStatus) -> Availability {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .unavailable
        }
    }

    // MARK: - Reading

    func accounts() async throws -> [WalletAccountRecord] {
        guard let store = guardedStore(), availability == .authorized else { return [] }
        return try await store.accounts(query: AccountQuery()).map(Self.record(from:))
    }

    /// Transactions dated within the last `days` days, newest first.
    func recentTransactions(days: Int) async throws -> [WalletTransactionRecord] {
        guard let store = guardedStore(), availability == .authorized else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\.transactionDate, order: .reverse)],
            predicate: #Predicate<FinanceKit.Transaction> { $0.transactionDate >= start }
        )
        return try await store.transactions(query: query).map(Self.record(from:))
    }

    // MARK: - Automatic import (explicit, separate opt-in)

    /// When automatic import was switched on, or nil when it is off. Only
    /// transactions dated after this are ever imported automatically, so
    /// switching it on never floods the ledger with history.
    var autoImportEnabledAt: Date? {
        defaults.object(forKey: Self.autoImportKey) as? Date
    }

    func setAutoImport(_ enabled: Bool) {
        if enabled {
            defaults.set(Date.now, forKey: Self.autoImportKey)
        } else {
            defaults.removeObject(forKey: Self.autoImportKey)
            clearHistoryTokens()
        }
    }

    /// "Stop Apple Wallet import": ends automatic import and forgets where it
    /// had got to. What was imported stays in the ledger as ordinary,
    /// editable transactions. The OS permission itself lives in Settings.
    func stopImport() {
        setAutoImport(false)
        defaults.removeObject(forKey: Self.linksKey)
    }

    /// New transactions since the last run, for each account. Runs when the
    /// app comes to the foreground. `isMonitoring: false` makes each history
    /// sequence end once it has delivered what is waiting.
    func runAutomaticImport(using useCase: ImportAppleWalletTransactionsUseCase) async -> AppleWalletImportResult? {
        guard let since = autoImportEnabledAt else { return nil }
        await refreshAvailability()
        guard let store = guardedStore(), availability == .authorized else { return nil }
        do {
            let accounts = try await accounts().filter(\.isSupported)
            var records: [WalletTransactionRecord] = []
            var newTokens: [UUID: FinanceStore.HistoryToken] = [:]
            for account in accounts {
                let history = store.transactionHistory(
                    forAccountID: account.id,
                    since: historyToken(for: account.id),
                    isMonitoring: false
                )
                for try await changes in history {
                    records += (changes.inserted + changes.updated).map(Self.record(from:))
                    newTokens[account.id] = changes.newToken
                }
            }
            let result = try await importRecords(records.filter { $0.date >= since }, accounts: accounts, using: useCase)
            // Tokens only advance once the import has landed; a failure
            // retries the same changes next time and dedupe absorbs repeats.
            for (accountID, token) in newTokens { saveHistoryToken(token, for: accountID) }
            return result
        } catch {
            Self.logger.error("Automatic Wallet import failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Importing

    func importRecords(
        _ records: [WalletTransactionRecord],
        accounts: [WalletAccountRecord],
        using useCase: ImportAppleWalletTransactionsUseCase
    ) async throws -> AppleWalletImportResult {
        let (result, links) = try await useCase.execute(records, accounts: accounts, links: accountLinks)
        accountLinks = links
        return result
    }

    private var accountLinks: [UUID: UUID] {
        get {
            let raw = defaults.dictionary(forKey: Self.linksKey) as? [String: String] ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                guard let wallet = UUID(uuidString: key), let ledger = UUID(uuidString: value) else { return nil }
                return (wallet, ledger)
            })
        }
        set {
            defaults.set(
                Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value.uuidString) }),
                forKey: Self.linksKey
            )
        }
    }

    private func historyToken(for accountID: UUID) -> FinanceStore.HistoryToken? {
        guard let data = defaults.data(forKey: Self.tokenKeyPrefix + accountID.uuidString) else { return nil }
        return try? JSONDecoder().decode(FinanceStore.HistoryToken.self, from: data)
    }

    private func saveHistoryToken(_ token: FinanceStore.HistoryToken, for accountID: UUID) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        defaults.set(data, forKey: Self.tokenKeyPrefix + accountID.uuidString)
    }

    private func clearHistoryTokens() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.tokenKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - FinanceKit → records

    nonisolated static func record(from account: FinanceKit.Account) -> WalletAccountRecord {
        let isLiability: Bool
        switch account {
        case .liability: isLiability = true
        case .asset: isLiability = false
        @unknown default: isLiability = false
        }
        return WalletAccountRecord(
            id: account.id,
            name: account.displayName,
            currencyCode: account.currencyCode,
            isLiability: isLiability
        )
    }

    nonisolated static func record(from transaction: FinanceKit.Transaction) -> WalletTransactionRecord {
        let direction: WalletTransactionRecord.Direction =
            transaction.creditDebitIndicator == .credit ? .credit : .debit
        return WalletTransactionRecord(
            id: transaction.id,
            accountID: transaction.accountID,
            amount: abs(transaction.transactionAmount.amount),
            currencyCode: transaction.transactionAmount.currencyCode,
            direction: direction,
            kind: kind(of: transaction.transactionType, direction: direction),
            status: status(of: transaction.status),
            date: transaction.transactionDate,
            merchantName: transaction.merchantName,
            description: transaction.transactionDescription
        )
    }

    /// A bill payment is spending when money leaves Apple Cash, and a card
    /// payment when it arrives on Apple Card — the direction decides.
    nonisolated static func kind(
        of type: FinanceKit.TransactionType,
        direction: WalletTransactionRecord.Direction
    ) -> WalletTransactionRecord.Kind {
        switch type {
        case .refund: .refund
        case .interest, .dividend, .directDeposit: .earning
        case .transfer, .deposit: .movement
        case .billPayment, .directDebit, .standingOrder, .loan: direction == .credit ? .movement : .spending
        default: .spending
        }
    }

    nonisolated static func status(of status: FinanceKit.TransactionStatus) -> WalletTransactionRecord.Status {
        switch status {
        case .booked: .booked
        case .rejected: .rejected
        default: .pending
        }
    }
}
#endif
