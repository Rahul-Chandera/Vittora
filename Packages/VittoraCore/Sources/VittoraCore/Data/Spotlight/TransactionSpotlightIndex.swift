import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// On-device Core Spotlight index for transactions (P2 / M2.7.6).
///
/// Amounts are visible in Spotlight outside App Lock by OS design — indexing is
/// gated by `AppUserDefaults.StandardKey.spotlightIndexingEnabled` (default ON).
public enum TransactionSpotlightIndex: Sendable {
    public static let domainIdentifier = "com.enerjiktech.vittora.transactions"

    /// UserDefaults key for "needs full reindex after this app update".
    public static let needsFullReindexKey = "vittora.spotlight.needsFullReindex.p2"

    public struct ItemDraft: Sendable, Equatable {
        public let id: UUID
        public let title: String
        public let contentDescription: String
        public let keywords: [String]

        public nonisolated init(
            id: UUID,
            title: String,
            contentDescription: String,
            keywords: [String]
        ) {
            self.id = id
            self.title = title
            self.contentDescription = contentDescription
            self.keywords = keywords
        }
    }

    /// Builds a Spotlight draft: title = payee/note; description = category + amount + date.
    public nonisolated static func makeDraft(
        transaction: TransactionEntity,
        payeeName: String?,
        categoryName: String?,
        currencyCode: String,
        date: Date = .now
    ) -> ItemDraft {
        let title: String = {
            if let payeeName, !payeeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return payeeName
            }
            if let note = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                return note
            }
            return transaction.type.displayName
        }()

        let amountText = transaction.amount.formatted(.currency(code: currencyCode))
        let dateText = transaction.date.formatted(date: .abbreviated, time: .omitted)
        let trimmedCategory = categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryText = trimmedCategory.isEmpty
            ? String(localized: "Uncategorized")
            : trimmedCategory

        let description = "\(categoryText) · \(amountText) · \(dateText)"

        var keywords: [String] = [categoryText, transaction.type.displayName]
        if let payeeName, !payeeName.isEmpty { keywords.append(payeeName) }
        if let note = transaction.note, !note.isEmpty { keywords.append(note) }

        _ = date // reserved for future expiration; keep signature stable
        return ItemDraft(
            id: transaction.id,
            title: title,
            contentDescription: description,
            keywords: keywords
        )
    }

    public nonisolated static func searchableItem(from draft: ItemDraft) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.displayName = draft.title
        attributes.contentDescription = draft.contentDescription
        attributes.keywords = draft.keywords
        attributes.title = draft.title
        attributes.contentURL = TransactionSpotlightDeepLink.url(for: draft.id)

        return CSSearchableItem(
            uniqueIdentifier: draft.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }

    /// Whether Settings allows indexing (default ON when unset).
    public nonisolated static func isIndexingEnabled(
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        userDefaults.object(forKey: AppUserDefaults.StandardKey.spotlightIndexingEnabled) as? Bool ?? true
    }

    public nonisolated static func setIndexingEnabled(
        _ enabled: Bool,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(enabled, forKey: AppUserDefaults.StandardKey.spotlightIndexingEnabled)
    }

    public nonisolated static func needsFullReindex(
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        userDefaults.object(forKey: needsFullReindexKey) as? Bool ?? true
    }

    public nonisolated static func markFullReindexComplete(
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(false, forKey: needsFullReindexKey)
    }

    /// Removes every Vittora transaction from Spotlight (factory reset / toggle OFF).
    public static func deleteAllIndexedTransactions() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: [domainIdentifier]
            ) { _ in
                continuation.resume()
            }
        }
    }

    /// Batch-indexes drafts (replaces prior domain contents when `replaceDomain` is true).
    public static func index(
        drafts: [ItemDraft],
        replaceDomain: Bool
    ) async {
        if replaceDomain {
            await deleteAllIndexedTransactions()
        }
        guard !drafts.isEmpty else { return }
        let items = drafts.map(searchableItem(from:))
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CSSearchableIndex.default().indexSearchableItems(items) { _ in
                continuation.resume()
            }
        }
    }

    /// Parses a Spotlight tap into a transaction UUID.
    public nonisolated static func transactionID(fromUserActivity activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else {
            return nil
        }
        return UUID(uuidString: identifier)
    }
}
