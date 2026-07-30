import Foundation

/// One sanitized non-fatal error for the user-controlled diagnostics payload.
/// Stores only type + code path — never record contents (amounts, notes, names).
public struct RecentErrorEntry: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let recordedAt: Date
    public let errorType: String
    public let codePath: String

    public init(
        id: UUID = UUID(),
        recordedAt: Date = .now,
        errorType: String,
        codePath: String
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.errorType = String(errorType.prefix(120))
        self.codePath = String(codePath.prefix(200))
    }
}

/// In-memory ring buffer (last 50) mirrored to the App Group suite so entries
/// survive relaunch. Cleared on demand from Contact Support and on factory reset.
public final class RecentErrorLogStore: @unchecked Sendable {
    public static let shared = RecentErrorLogStore()

    public static let storageKey = "vittora.recentErrorLog"
    public static let maxEntries = 50

    private let lock = NSLock()
    private let defaults: UserDefaults
    private var memory: [RecentErrorEntry]

    public init(defaults: UserDefaults = AppUserDefaults.appGroup) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([RecentErrorEntry].self, from: data) {
            memory = Array(decoded.suffix(Self.maxEntries))
        } else {
            memory = []
        }
    }

    public func record(errorType: String, codePath: String) {
        let entry = RecentErrorEntry(errorType: errorType, codePath: codePath)
        lock.lock()
        defer { lock.unlock() }
        memory.append(entry)
        if memory.count > Self.maxEntries {
            memory.removeFirst(memory.count - Self.maxEntries)
        }
        persistLocked()
    }

    public func recentEntries(limit: Int = maxEntries) -> [RecentErrorEntry] {
        lock.lock()
        defer { lock.unlock() }
        let cap = min(max(limit, 1), Self.maxEntries)
        return Array(memory.suffix(cap))
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        memory = []
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
