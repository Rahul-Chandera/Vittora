import Foundation
import OSLog
import VittoraCore

/// Keeps Core Spotlight in sync with the ledger (P2).
///
/// Batch reindex on `notifyChanged(.transactions)` at background priority;
/// full domain replace on first launch after the Spotlight update (or when the
/// Settings toggle turns back ON).
@MainActor
final class TransactionSpotlightCoordinator {
    private let transactionRepository: any TransactionRepository
    private let payeeRepository: any PayeeRepository
    private let categoryRepository: any CategoryRepository
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.enerjiktech.vittora",
        category: "Spotlight"
    )

    private var syncTask: Task<Void, Never>?

    init(
        transactionRepository: any TransactionRepository,
        payeeRepository: any PayeeRepository,
        categoryRepository: any CategoryRepository
    ) {
        self.transactionRepository = transactionRepository
        self.payeeRepository = payeeRepository
        self.categoryRepository = categoryRepository
    }

    /// Schedules a background sync. Coalesces rapid `notifyChanged` bursts.
    func scheduleSync(forceFullReindex: Bool = false) {
        syncTask?.cancel()
        syncTask = Task(priority: .background) { [weak self] in
            // Brief debounce so bursty saves collapse into one index pass.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.syncNow(forceFullReindex: forceFullReindex)
        }
    }

    func syncNow(forceFullReindex: Bool = false) async {
        guard TransactionSpotlightIndex.isIndexingEnabled() else {
            await TransactionSpotlightIndex.deleteAllIndexedTransactions()
            return
        }

        let replaceDomain = forceFullReindex || TransactionSpotlightIndex.needsFullReindex()

        do {
            let drafts = try await buildDrafts()
            await TransactionSpotlightIndex.index(drafts: drafts, replaceDomain: replaceDomain)
            if replaceDomain {
                TransactionSpotlightIndex.markFullReindexComplete()
            }
        } catch {
            logger.error("Spotlight sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Settings toggle OFF — clear index immediately.
    func clearIndex() async {
        syncTask?.cancel()
        await TransactionSpotlightIndex.deleteAllIndexedTransactions()
    }

    /// Settings toggle ON — full reindex.
    func enableAndReindex() async {
        TransactionSpotlightIndex.setIndexingEnabled(true)
        // Force a domain replace so stale rows never linger after a toggle cycle.
        UserDefaults.standard.set(true, forKey: TransactionSpotlightIndex.needsFullReindexKey)
        await syncNow(forceFullReindex: true)
    }

    private func buildDrafts() async throws -> [TransactionSpotlightIndex.ItemDraft] {
        let transactions = try await transactionRepository.fetchAll(filter: nil)
        let payees = try await payeeRepository.fetchAll()
        let categories = try await categoryRepository.fetchAll()
        let payeeNames = Dictionary(uniqueKeysWithValues: payees.map { ($0.id, $0.name) })
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.displayName) })
        let currencyCode = UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.currencyCode)
            ?? CurrencyDefaults.code

        return transactions.map { tx in
            TransactionSpotlightIndex.makeDraft(
                transaction: tx,
                payeeName: tx.payeeID.flatMap { payeeNames[$0] },
                categoryName: tx.categoryID.flatMap { categoryNames[$0] },
                currencyCode: currencyCode
            )
        }
    }
}
