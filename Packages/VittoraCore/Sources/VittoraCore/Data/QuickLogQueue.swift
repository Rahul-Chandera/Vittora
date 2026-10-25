import Foundation

/// An expense captured outside the app, waiting for the app to turn it into a
/// transaction: a widget preset tap (M2.7.5), or the Log Expense Shortcuts actions.
///
/// The fields after `createdAt` arrived with the Shortcuts actions. They are optional so
/// entries queued by an older build still decode: a missing key reads as nil.
public struct QuickLogEntry: Identifiable, Hashable, Sendable, Codable {
    public nonisolated let id: UUID
    public nonisolated let amount: Decimal
    public nonisolated let categoryID: UUID?
    public nonisolated let note: String?
    public nonisolated let createdAt: Date
    /// A merchant or payee name, matched to an existing payee by name when the app books it.
    public nonisolated let payeeName: String?
    /// ISO currency code; nil means the app's default currency.
    public nonisolated let currencyCode: String?
    /// `PaymentMethod` raw value; nil means the transaction default.
    public nonisolated let paymentMethod: String?

    public nonisolated init(
        id: UUID = UUID(),
        amount: Decimal,
        categoryID: UUID? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        payeeName: String? = nil,
        currencyCode: String? = nil,
        paymentMethod: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.categoryID = categoryID
        self.note = note
        self.createdAt = createdAt
        self.payeeName = payeeName
        self.currencyCode = currencyCode
        self.paymentMethod = paymentMethod
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

    /// Posted in-process after a Shortcuts action queues an entry, so an app that is
    /// already in front books it now instead of at its next activation.
    public nonisolated static let didEnqueueNotification = Notification.Name("vittora.quicklog.didEnqueue")

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
