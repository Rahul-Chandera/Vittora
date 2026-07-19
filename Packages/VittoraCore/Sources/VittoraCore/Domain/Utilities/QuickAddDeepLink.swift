import Foundation

/// Custom URL scheme for opening Quick Entry with a preselected type (W4).
///
/// Format: `vittora://add?type=expense|income|transfer`
public enum QuickAddDeepLink: Sendable {
    public static let scheme = "vittora"
    public static let host = "add"

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
}
