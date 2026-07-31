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
    // COLOUR MODEL (see VColors.onAccent / accentOnSurface / iconTint):
    //   fills      -> accent(_:)          + onAccent(for:) as the glyph/label colour
    //   on a card  -> accentOnSurface(_:) or iconTint(_:), never accent(_:) itself
    // One value cannot do both: a fill light enough to match the app icon is far too
    // light to read as text on white. That is why these are separate tokens.
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

    // MARK: - Accent pairings

    /// Glyph/label colour to use ON an `accent(_:)` fill.
    ///
    /// Chosen by luminance rather than hardcoded, because the accents do not agree:
    /// brandGreen (#3FCFA4) needs black (10.7:1) while blue/purple/orange need white
    /// (~4.6:1). Hardcoding either one is what left "Get Started" reading black on a
    /// dark green fill.
    static func onAccent(for accent: SettingsViewModel.AccentColor) -> Color {
        switch accent {
        case .brandGreen: return Color(red: 0.043, green: 0.106, blue: 0.090) // near-black, keeps a green cast
        case .blue, .purple, .orange: return .white
        }
    }

    /// Glyph/label colour for the *current* accent fill.
    static var onPrimary: Color { onAccent(for: currentAccent) }

    /// Accent used as a FOREGROUND on `background` / `secondaryBackground`.
    ///
    /// Scheme-adaptive: a single value cannot clear AA on both white and near-black.
    /// Light-mode values are darkened until they clear 4.5:1 on secondarySystemBackground
    /// (#F2F2F7); dark-mode values are the fill colours, which clear it on #1C1C1E.
    static func accentOnSurface(_ accent: SettingsViewModel.AccentColor) -> Color {
        switch accent {
        case .brandGreen: return adaptive(light: (0.122, 0.486, 0.376),  dark: (0.247, 0.812, 0.643)) // #1F7C60 / #3FCFA4
        case .blue:       return adaptive(light: (0.208, 0.435, 0.745),  dark: (0.314, 0.522, 0.808)) // #356FBE / #5085CE
        case .purple:     return adaptive(light: (0.537, 0.329, 0.773),  dark: (0.608, 0.435, 0.808)) // #8954C5 / #9B6FCE
        case .orange:     return adaptive(light: (0.686, 0.337, 0.000),  dark: (0.816, 0.400, 0.000)) // #AF5600 / #D06600
        }
    }

    /// Accent-as-foreground for the current accent.
    static var primaryOnSurface: Color { accentOnSurface(currentAccent) }

    /// Hues for decorative list/grid icons.
    ///
    /// Sized against the *tinted circle they sit in*, not the bare card. The 14%
    /// tint lifts the local background well above the card, and tints computed
    /// against the card alone measured ~3.8:1 in place — the onboarding audit
    /// caught exactly that. Each value clears 4.5:1 against its own tinted
    /// backing in both schemes: the text threshold, stricter than the 3:1
    /// SC 1.4.11 asks of non-text UI.
    /// Callers must use `iconTintFill` for the backing so the pairing holds.
    enum IconTint { case green, blue, orange, purple, red, teal, indigo, pink }

    static func iconTint(_ tint: IconTint) -> Color {
        switch tint {
        case .green:  return adaptive(light: (0.106, 0.431, 0.333), dark: (0.161, 0.647, 0.502)) // #1B6E55 / #29A580
        case .blue:   return adaptive(light: (0.184, 0.384, 0.659), dark: (0.400, 0.584, 0.831)) // #2F62A8 / #6695D4
        case .orange: return adaptive(light: (0.608, 0.298, 0.000), dark: (0.902, 0.443, 0.000)) // #9B4C00 / #E67100
        case .purple: return adaptive(light: (0.490, 0.263, 0.749), dark: (0.663, 0.510, 0.835)) // #7D43BF / #A982D5
        case .red:    return adaptive(light: (0.733, 0.106, 0.125), dark: (0.918, 0.412, 0.427)) // #BB1B20 / #EA696D
        case .teal:   return adaptive(light: (0.035, 0.424, 0.424), dark: (0.051, 0.639, 0.639)) // #096C6C / #0DA3A3
        case .indigo: return adaptive(light: (0.286, 0.275, 0.702), dark: (0.561, 0.553, 0.824)) // #4946B3 / #8F8DD2
        case .pink:   return adaptive(light: (0.706, 0.129, 0.384), dark: (0.890, 0.412, 0.624)) // #B42162 / #E3699F
        }
    }

    /// Light/dark pair as one colour. Falls back to the light value where the
    /// platform gives us no trait callback.
    /// Backing wash for an `iconTint` glyph. Keep these in step: the tint values
    /// are solved for this exact alpha.
    static func iconTintFill(_ tint: IconTint) -> Color { iconTint(tint).opacity(0.14) }

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }

    static func accent(
        _ accent: SettingsViewModel.AccentColor,
        for _: ColorScheme
    ) -> Color {
        return self.accent(accent)
    }

    static func accent(_ accent: SettingsViewModel.AccentColor) -> Color {
        // Fill colours only. The correct glyph colour is whichever of black or
        // white contrasts better — use onAccent(for:), never a hardcoded value:
        // brandGreen takes black (10.7:1), the others take white (~4.6:1).
        // Never use these as a foreground on a card; use accentOnSurface(_:).
        switch accent {
        case .brandGreen: return Color(red: 0.247059, green: 0.811765, blue: 0.643137) // #3FCFA4 — sampled from the app icon
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
