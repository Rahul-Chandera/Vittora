import Foundation

/// Custom URL scheme for opening a split group from a shared invite (K3 / share-out V1).
///
/// V1 uses ShareLink text + this deep link instead of CKShare. Recipients with Vittora
/// installed can jump straight to the group; others see the balance summary in the message.
enum SplitGroupDeepLink {
    nonisolated static let scheme = "vittora"
    nonisolated static let host = "splits"
    nonisolated private static let groupPathPrefix = "/group/"

    nonisolated static func url(for groupID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "\(groupPathPrefix)\(groupID.uuidString)"
        return components.url ?? URL(fileURLWithPath: "/invalid-split-group-link")
    }

    nonisolated static func groupID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host
        else {
            return nil
        }

        let path = url.path
        guard path.hasPrefix(groupPathPrefix) else { return nil }
        let idString = String(path.dropFirst(groupPathPrefix.count))
        return UUID(uuidString: idString)
    }
}
