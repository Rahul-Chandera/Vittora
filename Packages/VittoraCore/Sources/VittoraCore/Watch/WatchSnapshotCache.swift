import Foundation

/// Disk cache shared by the watch app and its WidgetKit extension.
public struct WatchSnapshotCache: Sendable {
    public static let appGroupIdentifier = "group.com.enerjiktech.vittora.watch"

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func watchAppGroup(fileManager: FileManager = .default) throws -> Self {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return Self(fileURL: container.appendingPathComponent("watch-snapshot.json"))
    }

    public func load() -> WatchSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? WatchSnapshot.decodeFromTransport(data)
    }

    public func save(_ snapshot: WatchSnapshot) throws {
        try snapshot.encodeForTransport().write(to: fileURL, options: .atomic)
    }
}
