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
    static var primary: Color {
        accent(currentAccent)
    }
    static var primaryLight: Color { accent(currentAccent) }
    static var primaryDark: Color { accent(currentAccent) }

    // Semantic
    static let income = Color("VIncome")
    static let expense = Color("VExpense")
    static let transfer = Color("VTransfer")
    static let warning = Color("VWarning")
    static let savings = Color("VSavings")

    // Surfaces - use platform-adaptive colors
    #if os(macOS)
    static var background: Color {
        isOLEDBlack ? .black : Color(nsColor: .windowBackgroundColor)
    }
    // Cards must contrast with the white detail area the way iOS's
    // secondarySystemBackground contrasts with systemBackground —
    // controlBackgroundColor is white-on-white and made every card invisible.
    // OLED: secondary matches pure black so fill-safe accents still clear AA
    // when used as chrome text/icons on cards (0.11 grey only yields ~3.7:1).
    static var secondaryBackground: Color {
        isOLEDBlack ? .black : Color(nsColor: .quaternarySystemFill)
    }
    static var tertiaryBackground: Color {
        isOLEDBlack ? Color(red: 0.08, green: 0.08, blue: 0.085) : Color(nsColor: .textBackgroundColor)
    }
    static var groupedBackground: Color {
        isOLEDBlack ? .black : Color(nsColor: .windowBackgroundColor)
    }
    #else
    static var background: Color {
        isOLEDBlack ? .black : Color(uiColor: .systemBackground)
    }
    static var secondaryBackground: Color {
        isOLEDBlack ? .black : Color(uiColor: .secondarySystemBackground)
    }
    static var tertiaryBackground: Color {
        isOLEDBlack ? Color(red: 0.08, green: 0.08, blue: 0.085) : Color(uiColor: .tertiarySystemBackground)
    }
    static var groupedBackground: Color {
        isOLEDBlack ? .black : Color(uiColor: .systemGroupedBackground)
    }
    #endif

    // Text — WCAG AA (≥4.5:1) on systemBackground and secondarySystemBackground.
    // System secondaryLabel/tertiaryLabel fail Apple's contrast audit on card surfaces.
    // Values keep extra headroom for AccessibilityXL and denser scripts (e.g. Devanagari),
    // and stay AA on OLED black / OLED secondary surfaces as well as light mode.
    //
    // Accents (primary / income / expense / warning) clear AA as text on pure black or
    // white, but fail on secondarySystemBackground and tinted chips. Prefer textPrimary
    // for icons and labels on cards; keep accents for fills, progress rings, and FABs.
    #if os(macOS)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.820, green: 0.820, blue: 0.839, alpha: 1) // #D1D1D6
            : NSColor(srgbRed: 0.184, green: 0.184, blue: 0.200, alpha: 1) // #2F2F33
    })
    static let textTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.753, green: 0.753, blue: 0.773, alpha: 1) // #C0C0C5
            : NSColor(srgbRed: 0.282, green: 0.282, blue: 0.298, alpha: 1) // #48484C
    })
    #else
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.820, green: 0.820, blue: 0.839, alpha: 1) // #D1D1D6
            : UIColor(red: 0.184, green: 0.184, blue: 0.200, alpha: 1) // #2F2F33
    })
    static let textTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.753, green: 0.753, blue: 0.773, alpha: 1) // #C0C0C5
            : UIColor(red: 0.282, green: 0.282, blue: 0.298, alpha: 1) // #48484C
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

    static func accent(
        _ accent: SettingsViewModel.AccentColor,
        for _: ColorScheme
    ) -> Color {
        return self.accent(accent)
    }

    static func accent(_ accent: SettingsViewModel.AccentColor) -> Color {
        // Fill-safe accents: white glyphs on these clears AA, and the hue still
        // clears AA as text on pure black / white. Do not lighten the dark
        // variants further — that breaks white-on-accent controls (FAB).
        // Icons/labels on elevated OLED secondary surfaces must not rely on
        // these as the sole foreground; use textPrimary there instead.
        switch accent {
        case .brandGreen: return Color(red: 0.00, green: 0.525490, blue: 0.403922) // #008667
        case .blue:       return Color(red: 0.227451, green: 0.462745, blue: 0.784314) // #3A76C8
        case .purple:     return Color(red: 0.556863, green: 0.360784, blue: 0.784314) // #8E5CC8
        case .orange:     return Color(red: 0.725490, green: 0.356863, blue: 0.00) // #B95B00
        }
    }

    private static var currentAccent: SettingsViewModel.AccentColor {
        SettingsViewModel.AccentColor(
            rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.accentColor) ?? ""
        ) ?? .brandGreen
    }

    private static var isOLEDBlack: Bool {
        UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appearanceMode)
            == SettingsViewModel.AppearanceMode.oledBlack.rawValue
    }
}
