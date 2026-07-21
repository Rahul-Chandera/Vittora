import Foundation

/// Custom URL scheme for opening a transaction from Spotlight (P2).
///
/// Format: `vittora://transaction/<uuid>`
public enum TransactionSpotlightDeepLink: Sendable {
    public static let scheme = "vittora"
    public static let host = "transaction"

    /// Builds `vittora://transaction/<uuid>` for a known transaction.
    public static func url(for transactionID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(transactionID.uuidString)"
        return components.url ?? URL(fileURLWithPath: "/invalid-transaction-spotlight-link")
    }

    /// `true` when the URL is a `vittora://transaction` link (valid or not).
    public static func isTransactionURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == host
    }

    /// Parses a transaction UUID from a Spotlight deep link, or `nil` if malformed.
    public static func transactionID(from url: URL) -> UUID? {
        guard isTransactionURL(url) else { return nil }
        let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }
}
