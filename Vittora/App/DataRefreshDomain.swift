import Foundation
import VittoraCore

/// Per-domain refresh tokens so list screens refetch only when their data changes.
enum DataRefreshDomain: String, CaseIterable, Hashable, Sendable {
    case transactions
    case accounts
    case budgets
    case categories
    case payees
    case debt
    case recurring
    case splits
    case savings
}

struct DashboardRefreshToken: Equatable, Sendable {
    let transactions: Int
    let accounts: Int
    let budgets: Int
    let recurring: Int
}
