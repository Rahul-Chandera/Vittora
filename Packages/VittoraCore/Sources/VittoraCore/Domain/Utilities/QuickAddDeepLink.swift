import Foundation

/// Custom URL scheme for opening Quick Entry with a preselected type (W4).
///
/// Format: `vittora://add?type=expense|income|transfer`
public enum QuickAddDeepLink: Sendable {
    public static let scheme = "vittora"
    public static let host = "add"

    /// App Group key for AddExpenseIntent when the host handler is not yet registered.
    public nonisolated static let pendingIntentDestinationKey = "vittora.pendingQuickAddFromIntent"

    public enum Destination: String, Sendable, Hashable, CaseIterable {
        case expense
        case income
        case transfer
    }

    /// Builds `vittora://add?type=…` for a known destination.
    public static func url(for destination: Destination) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "type", value: destination.rawValue)]
        return components.url ?? URL(fileURLWithPath: "/invalid-quick-add-link")
    }

    /// `true` when the URL is a `vittora://add` link (valid or not).
    public static func isQuickAddURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == host
    }

    /// Parses a valid quick-add destination, or `nil` for unknown/malformed types.
    public static func destination(from url: URL) -> Destination? {
        guard isQuickAddURL(url) else { return nil }

        let typeValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "type" })?
            .value?
            .lowercased()

        guard let typeValue else { return nil }
        return Destination(rawValue: typeValue)
    }

    // MARK: - App Intent bridge (W5)

    @MainActor
    private static var openHandler: ((Destination) -> Void)?

    /// Host app registers once so intents reuse `AppState.openFromURL` (W4 path).
    @MainActor
    public static func registerOpenHandler(_ handler: @escaping (Destination) -> Void) {
        openHandler = handler
        if let pending = consumePendingIntentDestination() {
            handler(pending)
        }
    }

    /// AddExpenseIntent entry point — opens via the W4 handler or stashes for cold start.
    @MainActor
    public static func requestFromIntent(_ destination: Destination) {
        if let openHandler {
            openHandler(destination)
        } else {
            AppUserDefaults.appGroup.set(destination.rawValue, forKey: pendingIntentDestinationKey)
        }
    }

    /// Consumes a cold-start stash written before the host handler was ready.
    public nonisolated static func consumePendingIntentDestination() -> Destination? {
        let defaults = AppUserDefaults.appGroup
        guard let raw = defaults.string(forKey: pendingIntentDestinationKey) else { return nil }
        defaults.removeObject(forKey: pendingIntentDestinationKey)
        return Destination(rawValue: raw)
    }
}
