import Foundation

/// StoreKit 2 product identifiers for the single paid tier, "Vittora Pro" (DEC-011).
enum ProProduct: String, CaseIterable, Sendable {
    case annual = "com.enerjiktech.vittora.pro.annual"
    case monthly = "com.enerjiktech.vittora.pro.monthly"
    case lifetime = "com.enerjiktech.vittora.pro.lifetime"

    nonisolated static let allIdentifiers: [String] = allCases.map(\.rawValue)

    nonisolated var isSubscription: Bool {
        switch self {
        case .annual, .monthly: true
        case .lifetime: false
        }
    }
}
