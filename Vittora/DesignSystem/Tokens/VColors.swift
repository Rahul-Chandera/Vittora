import SwiftUI

enum VColors {
    // Primary brand
    static let primary = Color("VPrimary")
    static let primaryLight = Color("VPrimaryLight")
    static let primaryDark = Color("VPrimaryDark")

    // Semantic
    static let income = Color("VIncome")
    static let expense = Color("VExpense")
    static let transfer = Color("VTransfer")
    static let warning = Color("VWarning")
    static let savings = Color("VSavings")

    // Surfaces - use platform-adaptive colors
    #if os(macOS)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color(nsColor: .textBackgroundColor)
    static let groupedBackground = Color(nsColor: .windowBackgroundColor)
    #else
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    #endif

    // Text - platform adaptive
    #if os(macOS)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    #else
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    #endif

    // Budget progress
    static let budgetSafe = Color.green
    static let budgetWarning = Color.orange
    static let budgetDanger = Color.red

    // Category default colors
    static let categoryColors: [Color] = [
        .blue, .green, .orange, .purple, .red,
        .teal, .indigo, .pink, .mint, .brown
    ]
}
