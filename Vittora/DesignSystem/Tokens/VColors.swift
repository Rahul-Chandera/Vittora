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
    // Literal values, NOT system colours. On macOS 26 windowBackgroundColor,
    // textBackgroundColor and controlBackgroundColor all resolve to #FFFFFF in
    // light and #1E1E1E in dark — measured, not assumed. So the page and the
    // cards drawn on it came out the same colour, 1.00:1, and every card on
    // every grouped screen was invisible.
    //
    // The comment this replaces already blamed controlBackgroundColor for being
    // white-on-white and moved to textBackgroundColor to escape it. That is no
    // longer an escape: all three are now the same value. Borrowing any system
    // surface colour for one half of a pair only works while Apple keeps them
    // distinct, and here they stopped being distinct.
    //
    // Values mirror the iOS pair so the two platforms read alike.
    static var groupedBackground: Color {
        isOLEDBlack
            ? .black
            : adaptive(light: (0.949, 0.949, 0.969),   // #F2F2F7, as iOS
                       dark: (0.118, 0.118, 0.118))    // #1E1E1E, the macOS window grey
    }
    // Card ON a grouped page — white on the grey page, the way iOS's
    // secondarySystemGroupedBackground pairs with systemGroupedBackground.
    // Distinct from secondaryBackground, which is the grey FILL that sits on
    // white surfaces (form fields, chips). Collapsing those two roles into one
    // token is what made past background sweeps fail with invisible
    // white-on-white chips.
    static var secondaryGroupedBackground: Color {
        isOLEDBlack
            ? .black
            : adaptive(light: (1.000, 1.000, 1.000),   // #FFFFFF
                       dark: (0.173, 0.173, 0.180))    // #2C2C2E, lifted off the page
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
    // See the macOS twin above for why this exists as its own role.
    // OLED mirrors secondaryBackground: cards sit on pure black.
    static var secondaryGroupedBackground: Color {
        isOLEDBlack ? .black : Color(uiColor: .secondarySystemGroupedBackground)
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

    /// Selected-row fill for the iPad/Mac split lists.
    ///
    /// Deliberately NOT the accent. `List(selection:)` tints the selected row
    /// with the inherited accent, which put a solid brand-green bar under rows
    /// whose content keeps its own semantic colours — a red expense amount on
    /// brand green. Owner decision (2026-08-01): selection is neutral, so row
    /// content stays readable whatever accent is chosen and whatever colour an
    /// individual amount happens to be.
    /// A control that is present but currently unavailable — a Save button
    /// with required fields still empty, for example.
    ///
    /// Needed because SwiftUI's own disabled rendering is roughly 30% opacity,
    /// which fails the contrast audit. af8b34c8 worked around that by dropping
    /// `.disabled()` entirely and guarding inside the action, so the button
    /// stayed fully enabled-looking and gave no hint that anything was missing.
    /// An explicit colour lets the control BE disabled and still measure 5.07:1
    /// on a white card.
    ///
    /// Same value as placeholderText today; kept separate because "unavailable
    /// control" and "hint text" are different roles that may diverge.
    /// Label for a disabled filled control.
    ///
    /// A fixed dark grey was enough while only light mode was checked, then the
    /// OLED Black audit failed on the disabled Save: the fill under it is
    /// `groupedBackground`, which is pure black in that theme, and #5A5A5F on
    /// black measures about 3.1:1. `controlDisabled` is the neighbouring token
    /// but sits at 4.54:1 on light grey, close enough to the threshold that the
    /// audit called it "nearly passed". This clears both ends with headroom.
    static var controlDisabledOnFill: Color {
        adaptive(light: (0.352941, 0.352941, 0.372549),   // #5A5A5F, 6.1:1 on #F2F2F7
                 dark: (0.627451, 0.627451, 0.658824))    // #A0A0A8, 8.2:1 on black
    }

    /// The text insertion caret.
    ///
    /// Not `textPrimary`. That is `Color(nsColor: .labelColor)`, and when the
    /// app's Appearance is Light while macOS itself is Dark, a caret tinted
    /// with it came out white on a light field — measured 1.1:1, so there was
    /// no visible cursor. `@Environment(\.colorScheme)` is no good here
    /// either: inside a sheet it reports the SYSTEM appearance, not the one
    /// `preferredColorScheme` is rendering, so it picks the wrong branch.
    ///
    /// `adaptive` resolves against the NSAppearance actually drawing the view,
    /// which is the only one of the three that follows what the user sees.
    static var textCursor: Color {
        adaptive(light: (0.109804, 0.109804, 0.117647),   // #1C1C1E
                 dark: (0.921569, 0.921569, 0.960784))    // #EBEBF5
    }

    static var controlDisabled: Color {
        adaptive(light: (0.431, 0.431, 0.451),   // #6E6E73
                 dark: (0.557, 0.557, 0.576))    // #8E8E93
    }

    /// Placeholder text inside an input field.
    ///
    /// af8b34c8 (the P1 accessibility pass) set these to textPrimary, which is
    /// black — so "Amount" read as a label and the field did not look editable.
    /// The system placeholder colour is the other extreme at 1.68:1. This is
    /// the middle: 5.07:1 on a white card and 4.54:1 on the grouped page, so it
    /// clears AA on both while staying clearly lighter than entered text.
    static var placeholderText: Color {
        adaptive(light: (0.431, 0.431, 0.451),   // #6E6E73
                 dark: (0.557, 0.557, 0.576))    // #8E8E93
    }

    /// Unfilled portion of a progress bar or ring.
    ///
    /// Its own token because a track has to read against BOTH a white card and
    /// the grouped grey page, and no existing surface token does. Using
    /// secondaryBackground here measured 1.00:1 on the page — the identical
    /// colour — so the Budget Details ring had no visible track at all.
    /// #D1D1D6 gives 1.52:1 on white and 1.36:1 on the page.
    static var progressTrack: Color {
        adaptive(light: (0.820, 0.820, 0.839),   // #D1D1D6
                 dark: (0.227, 0.227, 0.235))    // #3A3A3C
    }

    static var rowSelection: Color {
        adaptive(light: (0.890, 0.890, 0.906),   // #E3E3E7
                 dark: (0.173, 0.173, 0.180))    // #2C2C2E
    }

    // Budget progress — reuse WCAG-AA semantic tokens (system green/red fail 4.5:1 as text)
    static let budgetSafe = income

    // Fill-only variant of budgetSafe. `income` has to clear 4.5:1 as text
    // (34 call sites use it as a label colour), which pins it dark. A bar or
    // ring fill only owes 3:1 against its white track, so it can be lighter.
    // Use this ONLY where the colour is never also the label.
    static var budgetSafeFill: Color {
        adaptive(light: (0.180392, 0.619608, 0.419608),  // #2E9E6B — 3.38:1 on white
                 dark: (0.505882, 0.788235, 0.584314))   // #81C995 — matches VIncome dark
    }
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
    /// White on every accent: brandGreen 5.04:1, blue 4.56:1, purple 4.65:1,
    /// orange 4.61:1. Kept as a function rather than a constant so that a future
    /// accent light enough to need dark text cannot silently ship unreadable.
    static func onAccent(for accent: SettingsViewModel.AccentColor) -> Color {
        // Every accent fill is now dark enough for white, so this is uniform —
        // it stays a function so a future lighter accent cannot silently ship
        // an unreadable pairing.
        switch accent {
        // Owner decision (2026-08-01): white labels on the brand green.
        // NOTE: white on #3FCFA4 is 1.97:1, below the 4.5:1 AA text minimum and
        // below even the 3:1 large-text bar. Recorded here so the next person to
        // read this knows it is a deliberate choice, not an oversight.
        case .brandGreen, .blue, .purple, .orange: return .white
        }
    }

    /// Glyph/label colour for the *current* accent fill.
    static var onPrimary: Color { onAccent(for: currentAccent) }

    /// Accent used as a FOREGROUND on `background` / `secondaryBackground`.
    ///
    /// DEC-012 puts #3FCFA4 on every brand SURFACE (fills, the FAB, hero icons).
    /// This token is the other case: brand green as small text or a glyph directly
    /// on a background. #3FCFA4 there is 1.97:1 on white — for a 17pt link or a
    /// checkmark that is not "slightly under AA", it is hard to read. So this
    /// stays the readable same-hue variant, which is why a darker green still
    /// appears on links and the selected tab. Widening DEC-012 to cover these
    /// would mean excluding contrast on most screens, not one pairing.
    ///
    /// Dark variants target ~5.5:1 rather than the 4.5:1 minimum. This token also
    /// colours the selected tab, and at a bare 4.50:1 the audit intermittently
    /// reported contrast failures when element frames came back as clipped
    /// strips. Headroom is cheaper than chasing that.
    static func accentOnSurface(_ accent: SettingsViewModel.AccentColor) -> Color {
        switch accent {
        case .brandGreen: return adaptive(light: (0.121569, 0.490196, 0.380392), dark: (0.247, 0.812, 0.643)) // #1F7D61 / #3FCFA4
        case .blue:       return adaptive(light: (0.208, 0.435, 0.745),  dark: (0.404, 0.584, 0.831)) // #356FBE / #6795D4
        case .purple:     return adaptive(light: (0.537, 0.329, 0.773),  dark: (0.659, 0.510, 0.831)) // #8954C5 / #A882D4
        case .orange:     return adaptive(light: (0.686, 0.337, 0.000),  dark: (0.910, 0.447, 0.000)) // #AF5600 / #E87200
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
    /// are solved against this alpha.
    ///
    /// 0.10 rather than 0.14 for headroom. At 0.14 the worst pairing lands on
    /// 4.50:1 — nominally a pass, but close enough to the line that the audit
    /// reported a contrast failure on the Dashboard when element frames came
    /// back as clipped strips. 0.10 gives 4.78:1 worst case and the wash still
    /// reads as a tint.
    static func iconTintFill(_ tint: IconTint) -> Color { iconTint(tint).opacity(0.10) }

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        // The provider closures MUST be `@Sendable`. UIKit and AppKit resolve a
        // dynamic colour on whatever thread is rendering, and SwiftUI's shape
        // style resolution is not always the main one. Without this, the
        // closure inherits the caller's actor isolation and the Swift 6
        // isolation check traps (EXC_BREAKPOINT in _dispatch_assert_queue_fail)
        // the first time a token is resolved off-main. Both tuples are
        // Sendable, so nothing else is captured.
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { @Sendable appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { @Sendable traits in
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
        // Fill colours only; pair with onAccent(for:), never a hardcoded value.
        //
        // brandGreen is #3FCFA4, the app icon colour, with white content on it.
        // That pairing is 1.97:1 and does NOT meet WCAG AA — an accepted,
        // owner-approved exception recorded as DEC-012. Do not "fix" it by
        // darkening the green or flipping the label to black without reopening
        // that decision.
        switch accent {
        case .brandGreen: return Color(red: 0.247059, green: 0.811765, blue: 0.643137) // #3FCFA4
        case .blue:       return Color(red: 0.227451, green: 0.462745, blue: 0.784314) // #3A76C8
        case .purple:     return Color(red: 0.556863, green: 0.360784, blue: 0.784314) // #8E5CC8
        case .orange:     return Color(red: 0.725490, green: 0.356863, blue: 0.00) // #B95B00
        }
    }

    // Routed through ThemeState so SwiftUI sees the dependency and re-renders
    // on change; a direct UserDefaults read does not invalidate any view.
    private static var currentAccent: SettingsViewModel.AccentColor {
        ThemeState.shared.accent
    }

    private static var isOLEDBlack: Bool {
        ThemeState.shared.isOLEDBlack
    }
}
