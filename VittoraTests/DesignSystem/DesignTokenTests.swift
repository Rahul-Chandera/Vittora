import SwiftUI
import Testing
@testable import Vittora

/// Locks the design tokens to their intended values.
///
/// Every theming defect in this area was caught by a human looking at a
/// screenshot, never by CI: the accessibility audits check contrast, Dynamic
/// Type and hit targets, and have no opinion about what colour a thing is
/// *meant* to be. A token can silently drift to a different green — or to
/// `Color.primary`, which is how the accent swatches turned black — and every
/// existing test still passes.
///
/// What these DO cover: the token layer. A green drifting away from the brand
/// value, an accent losing its white content pairing, and — most usefully — the
/// accent failing to propagate, which is what made "Apply Appearance" look like
/// it did nothing.
///
/// What these do NOT cover: a *view* reaching for the wrong token. The black
/// accent swatches (`.fill(Color.primary)`) and the invisible profile avatar
/// (`.fill(VColors.tertiaryBackground)` on a white card) were both view-level
/// mistakes with entirely correct tokens underneath. Catching that class needs
/// snapshot tests, which this project does not have; every such regression so
/// far has been found by a human looking at the screen.
@Suite("Design tokens")
@MainActor
struct DesignTokenTests {

    /// sRGB components, so two Colors can be compared by value.
    private func rgba(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return (0, 0, 0, 0)
        #endif
    }

    private func isApprox(_ lhs: Color, _ rhs: Color, tolerance: CGFloat = 0.01) -> Bool {
        let a = rgba(lhs), b = rgba(rhs)
        return abs(a.r - b.r) < tolerance && abs(a.g - b.g) < tolerance
            && abs(a.b - b.b) < tolerance && abs(a.a - b.a) < tolerance
    }

    @Test("brand green is the app icon colour #3FCFA4 (DEC-012)")
    func brandGreenMatchesAppIcon() {
        let expected = Color(red: 0.247059, green: 0.811765, blue: 0.643137)
        #expect(isApprox(VColors.accent(.brandGreen), expected),
                "brandGreen drifted away from #3FCFA4 — see DEC-012 before changing it")
    }

    @Test("content on every accent fill is white (DEC-012)")
    func accentFillsCarryWhiteContent() {
        for accent in SettingsViewModel.AccentColor.allCases {
            #expect(isApprox(VColors.onAccent(for: accent), .white),
                    "\(accent) fill should carry white content")
        }
    }

    @Test("the four accents resolve to four distinct, non-label colours")
    func accentsAreDistinctColours() {
        // NOTE: this checks the TOKENS, not the Appearance picker. The black-swatch
        // bug was a *view* using Color.primary instead of VColors.accent(accent),
        // which this cannot see. Catching that needs snapshot tests — see the
        // suite comment.
        for accent in SettingsViewModel.AccentColor.allCases {
            #expect(!isApprox(VColors.accent(accent), Color.primary),
                    "\(accent) swatch must not resolve to the label colour")
        }
        // …and the four must be distinguishable from each other.
        let all = SettingsViewModel.AccentColor.allCases.map { VColors.accent($0) }
        for i in all.indices {
            for j in all.indices where j > i {
                #expect(!isApprox(all[i], all[j]), "two accents resolve to the same colour")
            }
        }
    }

    @Test("primary follows the selected accent")
    func primaryTracksTheSelectedAccent() {
        #expect(isApprox(VColors.primary, VColors.accent(ThemeState.shared.accent)),
                "VColors.primary must resolve to the currently selected accent")
    }

    @Test("changing the accent updates the observable theme state")
    func accentChangePropagates() {
        let original = ThemeState.shared.accent
        defer { ThemeState.shared.accent = original }

        ThemeState.shared.accent = .purple
        #expect(isApprox(VColors.primary, VColors.accent(.purple)),
                "VColors read a stale accent — views would keep the old colour until relaunch")

        ThemeState.shared.accent = .orange
        #expect(isApprox(VColors.primary, VColors.accent(.orange)))
    }

    @Test("a fill token and its content token are never the same colour")
    func fillAndContentTokensDiffer() {
        // Also token-level. The invisible-avatar bug was a view picking
        // tertiaryBackground (white in light mode) for a circle on a white card;
        // no token was wrong, so this would not have caught it either.
        #expect(!isApprox(VColors.primary, VColors.onPrimary),
                "a fill and the content on it must not resolve to the same colour")
    }
}
