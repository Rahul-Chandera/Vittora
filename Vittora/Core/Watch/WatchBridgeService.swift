#if os(iOS)
import Foundation
import WatchConnectivity
import OSLog
import VittoraCore

/// Phone half of the WatchConnectivity bridge: pushes snapshots, commits queued expenses.
@MainActor
final class WatchBridgeService: NSObject {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "watch-bridge")

    private let session: any WatchSessionClient
    private let buildSnapshot: @MainActor () async throws -> WatchSnapshot
    private let commitExpense: @MainActor (QueuedWatchExpense) async throws -> Void
    private let presentError: @MainActor (String) -> Void
    private let notifyCommitted: @MainActor () -> Void

    private var isActivated = false
    private var pushTask: Task<Void, Never>?

    init(
        session: any WatchSessionClient = LiveWatchSessionClient(),
        buildSnapshot: @escaping @MainActor () async throws -> WatchSnapshot,
        commitExpense: @escaping @MainActor (QueuedWatchExpense) async throws -> Void,
        presentError: @escaping @MainActor (String) -> Void,
        notifyCommitted: @escaping @MainActor () -> Void = {}
    ) {
        self.session = session
        self.buildSnapshot = buildSnapshot
        self.commitExpense = commitExpense
        self.presentError = presentError
        self.notifyCommitted = notifyCommitted
        super.init()
    }

    func activate() {
        guard session.isSupported else { return }
        session.setDelegate(self)
        session.activate()
        isActivated = true
    }

    /// Rebuilds and pushes the latest snapshot (latest-wins via application context).
    func pushSnapshot() {
        guard session.isSupported else { return }
        pushTask?.cancel()
        pushTask = Task { @MainActor in
            do {
                let snapshot = try await buildSnapshot()
                let data = try snapshot.encodeForTransport()
                try session.updateApplicationContext([
                    WatchConnectivityPayloadKey.snapshotData: data,
                ])
            } catch {
                // Snapshot push failures are non-fatal; next foreground/change retries.
                Self.logger.error(
                    "Watch snapshot push failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Testable entry for received `transferUserInfo` payloads.
    func handleIncomingUserInfo(_ userInfo: [String: Any]) async {
        await handleParsedQueuedExpense(Self.parseQueuedExpense(userInfo))
    }

    private func handleParsedQueuedExpense(_ parsed: ParsedQueuedExpense) async {
        switch parsed {
        case .success(let expense):
            do {
                try await commitExpense(expense)
                notifyCommitted()
                pushSnapshot()
            } catch {
                presentError(
                    error.userFacingMessage(
                        fallback: String(localized: "We couldn't save the expense from Apple Watch.")
                    )
                )
            }
        case .failureMessage(let message):
            presentError(message)
        }
    }

    nonisolated private static func parseQueuedExpense(_ userInfo: [String: Any]) -> ParsedQueuedExpense {
        do {
            return .success(try QueuedWatchExpense.fromUserInfo(userInfo))
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return .failureMessage(String(localized: "We couldn't save the expense from Apple Watch."))
            }
            return .failureMessage(message)
        }
    }
}

enum ParsedQueuedExpense: Sendable {
    case success(QueuedWatchExpense)
    case failureMessage(String)
}

extension WatchBridgeService: WatchSessionClientDelegate {
    nonisolated func watchSessionActivationDidComplete() {
        Task { @MainActor in
            pushSnapshot()
        }
    }

    nonisolated func watchSessionDidReceiveParsedExpense(_ parsed: ParsedQueuedExpense) {
        Task { @MainActor in
            await handleParsedQueuedExpense(parsed)
        }
    }
}

@MainActor
protocol WatchSessionClient: AnyObject {
    var isSupported: Bool { get }
    func setDelegate(_ delegate: any WatchSessionClientDelegate)
    func activate()
    func updateApplicationContext(_ context: [String: Any]) throws
}

@MainActor
protocol WatchSessionClientDelegate: AnyObject {
    func watchSessionActivationDidComplete()
    func watchSessionDidReceiveParsedExpense(_ parsed: ParsedQueuedExpense)
}

@MainActor
final class LiveWatchSessionClient: NSObject, WatchSessionClient {
    private let session: WCSession
    private weak var clientDelegate: (any WatchSessionClientDelegate)?

    init(session: WCSession = .default) {
        self.session = session
        super.init()
    }

    var isSupported: Bool { WCSession.isSupported() }

    func setDelegate(_ delegate: any WatchSessionClientDelegate) {
        clientDelegate = delegate
        session.delegate = self
    }

    func activate() {
        session.activate()
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        try session.updateApplicationContext(context)
    }
}

extension LiveWatchSessionClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            clientDelegate?.watchSessionActivationDidComplete()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let parsed: ParsedQueuedExpense
        do {
            parsed = .success(try QueuedWatchExpense.fromUserInfo(userInfo))
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            parsed = .failureMessage(
                message.isEmpty
                    ? String(localized: "We couldn't save the expense from Apple Watch.")
                    : message
            )
        }
        Task { @MainActor in
            clientDelegate?.watchSessionDidReceiveParsedExpense(parsed)
        }
    }
}

// MARK: - Snapshot builder

enum WatchSnapshotBuilder {
    @MainActor
    static func build(
        provider: WidgetDataProvider,
        transactionRepository: any TransactionRepository,
        categoryRepository: any CategoryRepository
    ) async throws -> WatchSnapshot {
        let spending = try await provider.todaySpendingSnapshot()
        let budget = try await provider.budgetRemainingSnapshot()
        let categories = try await categoryRepository.fetchAll()
        let categoriesByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let recentEntities = try await transactionRepository.fetchPage(
            filter: nil,
            offset: 0,
            limit: 100
        )
        let recent = recentEntities.prefix(WatchSnapshot.maxRecentTransactions).map { transaction in
            WatchSnapshotTransaction(
                id: transaction.id,
                date: transaction.date,
                name: transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? transaction.type.displayName,
                categoryIcon: transaction.categoryID.flatMap { categoriesByID[$0]?.icon },
                amount: transaction.amount,
                type: transaction.type,
                categoryID: transaction.categoryID
            )
        }
        let expenseCategories = try await categoryRepository.fetchByType(.expense)
        let recentExpenseCategoryIDs = recentEntities.compactMap { transaction in
            transaction.type == .expense ? transaction.categoryID : nil
        }
        let usageCounts = Dictionary(grouping: recentExpenseCategoryIDs, by: { $0 }).mapValues(\.count)
        let firstUsage = Dictionary(
            recentExpenseCategoryIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: min
        )
        let quickCategories = expenseCategories.sorted { lhs, rhs in
            let lhsCount = usageCounts[lhs.id, default: 0]
            let rhsCount = usageCounts[rhs.id, default: 0]
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            let lhsUsage = firstUsage[lhs.id, default: .max]
            let rhsUsage = firstUsage[rhs.id, default: .max]
            if lhsUsage != rhsUsage { return lhsUsage < rhsUsage }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        .prefix(WatchSnapshot.maxQuickCategories)
        .map {
            WatchSnapshotCategory(id: $0.id, name: $0.displayName, icon: $0.icon, colorHex: $0.colorHex)
        }

        let generatedAt = Date.now
        return WatchSnapshot(
            todaySpend: spending.todayAmount,
            budgetSpent: budget.spent,
            budgetTotal: budget.total,
            budgetPeriodKey: WatchSnapshot.monthlyPeriodKey(for: generatedAt),
            recentTransactions: Array(recent),
            quickCategories: Array(quickCategories),
            currencyCode: spending.currencyCode,
            generatedAt: generatedAt
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
