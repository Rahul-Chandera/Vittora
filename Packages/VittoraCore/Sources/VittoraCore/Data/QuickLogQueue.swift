import Foundation

/// One tap on a widget preset, waiting for the app to turn it into a transaction (M2.7.5).
public struct QuickLogEntry: Identifiable, Hashable, Sendable, Codable {
    public nonisolated let id: UUID
    public nonisolated let amount: Decimal
    public nonisolated let categoryID: UUID?
    public nonisolated let note: String?
    public nonisolated let createdAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        amount: Decimal,
        categoryID: UUID? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.categoryID = categoryID
        self.note = note
        self.createdAt = createdAt
    }
}

/// A hand-off queue between the widget extension and the app.
///
/// The extension cannot write the ledger: `ModelContainerConfig.makeReadOnlyContainer`
/// opens the App Group store read-only with no migration plan, deliberately, because the
/// host app owns schema migrations. A widget process that could write would be a second
/// writer against a store it has no plan to migrate — after a schema change it would be
/// writing to a shape it does not understand. So the tap is recorded here and the app
/// commits it.
///
/// **One key per entry, never one array.** A shared array would be read-modify-write from
/// two processes, and the interleaving that loses an entry is the one where the user taps
/// the widget while the app is draining. Money that silently disappears is the worst bug
/// this feature could have, so appends never touch each other's keys.
public struct QuickLogQueue: Sendable {
    public nonisolated static let keyPrefix = "vittora.quicklog.entry."

    /// UserDefaults is thread-safe but not Sendable; the same `nonisolated(unsafe)` the
    /// reminder use cases already use for their injected suite.
    nonisolated(unsafe) private let defaults: UserDefaults

    public nonisolated init?(suiteName: String = AppGroupConfiguration.identifier) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    public nonisolated init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Records a tap. Returns false only when the entry cannot be encoded, which the
    /// caller should surface rather than swallow — a button that silently does nothing is
    /// indistinguishable from a broken one.
    @discardableResult
    public nonisolated func enqueue(_ entry: QuickLogEntry) -> Bool {
        guard entry.amount > 0, let data = try? JSONEncoder().encode(entry) else { return false }
        defaults.set(data, forKey: Self.keyPrefix + entry.id.uuidString)
        return true
    }

    /// Everything waiting, oldest first.
    ///
    /// An entry that cannot be decoded is dropped rather than throwing: a single corrupt
    /// value must not block every other pending entry from reaching the ledger.
    public nonisolated func pending() -> [QuickLogEntry] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.keyPrefix) }
            .compactMap { key -> QuickLogEntry? in
                guard let data = defaults.data(forKey: key) else { return nil }
                return try? JSONDecoder().decode(QuickLogEntry.self, from: data)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public nonisolated var pendingCount: Int {
        defaults.dictionaryRepresentation().keys.count { $0.hasPrefix(Self.keyPrefix) }
    }

    /// Removes one entry, by id.
    ///
    /// Called after the transaction is committed, never before: a crash between the two
    /// costs a duplicate the user can delete, while the other order costs a lost expense
    /// they will never know about.
    public nonisolated func remove(id: UUID) {
        defaults.removeObject(forKey: Self.keyPrefix + id.uuidString)
    }

    public nonisolated func removeAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
