import Foundation
import OSLog
import VittoraCore

protocol TransactionEditHistoryStoring: Sendable {
    func fetch(for transactionID: UUID) throws -> [TransactionEditRecord]
    func append(_ record: TransactionEditRecord) throws
    func delete(for transactionID: UUID) throws
}

enum TransactionEditHistoryStore {
    nonisolated static func clearAll(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: AppUserDefaults.StandardKey.transactionEditHistory)
    }
}

final class UserDefaultsTransactionEditHistoryStore: TransactionEditHistoryStoring, @unchecked Sendable {
    nonisolated(unsafe) private let userDefaults: UserDefaults
    nonisolated private let storageKey = AppUserDefaults.StandardKey.transactionEditHistory
    nonisolated private let lock = NSLock()

    nonisolated init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    nonisolated func fetch(for transactionID: UUID) throws -> [TransactionEditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return try decodeRecordsLocked()
            .filter { $0.transactionID == transactionID }
            .sorted { $0.editedAt > $1.editedAt }
    }

    nonisolated func append(_ record: TransactionEditRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        var records = try decodeRecordsLocked()
        records.append(record)
        try encodeRecordsLocked(records)
    }

    nonisolated func delete(for transactionID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        let records = try decodeRecordsLocked()
            .filter { $0.transactionID != transactionID }
        try encodeRecordsLocked(records)
    }

    nonisolated private func decodeRecordsLocked() throws -> [TransactionEditRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TransactionEditRecord].self, from: data)
    }

    nonisolated private func encodeRecordsLocked(_ records: [TransactionEditRecord]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        userDefaults.set(data, forKey: storageKey)
    }
}

/// Best-effort edit-history side effects after the ledger commit succeeds (K8).
/// Failures are logged only — they must not fail an already-committed update/delete.
enum TransactionEditHistorySideEffects {
    private static let logger = Logger(
        subsystem: "com.vittora.app",
        category: "transaction_edit_history"
    )

    static func recordEdit(
        _ useCase: RecordTransactionEditUseCase?,
        before: TransactionEntity,
        after: TransactionEntity
    ) {
        guard let useCase else { return }
        do {
            try useCase.execute(before: before, after: after)
        } catch {
            logger.error(
                "Edit history record failed for transaction id=\(before.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func clearHistory(
        _ store: (any TransactionEditHistoryStoring)?,
        transactionID: UUID
    ) {
        guard let store else { return }
        do {
            try store.delete(for: transactionID)
        } catch {
            logger.error(
                "Edit history delete failed for transaction id=\(transactionID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

struct RecordTransactionEditUseCase: Sendable {
    let store: any TransactionEditHistoryStoring

    func execute(before: TransactionEntity, after: TransactionEntity) throws {
        let changes = TransactionEditDiff.changes(from: before, to: after)
        guard !changes.isEmpty else { return }
        let record = TransactionEditRecord(
            transactionID: before.id,
            changes: changes
        )
        try store.append(record)
    }
}
