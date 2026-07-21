import SwiftUI
import VittoraCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

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
    // Cards must contrast with the white detail area the way iOS's
    // secondarySystemBackground contrasts with systemBackground —
    // controlBackgroundColor is white-on-white and made every card invisible.
    static let secondaryBackground = Color(nsColor: .quaternarySystemFill)
    static let tertiaryBackground = Color(nsColor: .textBackgroundColor)
    static let groupedBackground = Color(nsColor: .windowBackgroundColor)
    #else
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    #endif

    // Text — WCAG AA (≥4.5:1) on systemBackground and secondarySystemBackground.
    // System secondaryLabel/tertiaryLabel fail Apple's contrast audit on card surfaces.
    #if os(macOS)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.773, green: 0.773, blue: 0.788, alpha: 1) // #C5C5C9
            : NSColor(srgbRed: 0.235, green: 0.235, blue: 0.263, alpha: 1) // #3C3C43
    })
    static let textTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.682, green: 0.682, blue: 0.698, alpha: 1) // #AEAEB2
            : NSColor(srgbRed: 0.353, green: 0.353, blue: 0.369, alpha: 1) // #5A5A5E
    })
    #else
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.773, green: 0.773, blue: 0.788, alpha: 1) // #C5C5C9
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 1) // #3C3C43
    })
    static let textTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.682, green: 0.682, blue: 0.698, alpha: 1) // #AEAEB2
            : UIColor(red: 0.353, green: 0.353, blue: 0.369, alpha: 1) // #5A5A5E
    })
    #endif

    // Budget progress — reuse WCAG-AA semantic tokens (system green/red fail 4.5:1 as text)
    static let budgetSafe = income
    static let budgetWarning = warning
    static let budgetDanger = expense

    // Category default colors — WCAG AA (≥4.5:1) on white when used as icon/text tint
    static let categoryColors: [Color] = [
        Color(red: 0.00, green: 0.35, blue: 0.70), // blue
        Color(red: 0.11, green: 0.50, blue: 0.22), // green
        Color(red: 0.70, green: 0.35, blue: 0.00), // orange
        Color(red: 0.40, green: 0.20, blue: 0.65), // purple
        Color(red: 0.70, green: 0.13, blue: 0.12), // red
        Color(red: 0.00, green: 0.45, blue: 0.50), // teal
        Color(red: 0.25, green: 0.25, blue: 0.65), // indigo
        Color(red: 0.70, green: 0.15, blue: 0.40), // pink
        Color(red: 0.10, green: 0.45, blue: 0.40), // mint
        Color(red: 0.45, green: 0.30, blue: 0.15)  // brown
    ]
}
