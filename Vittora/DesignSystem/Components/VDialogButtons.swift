import SwiftUI

/// The confirm and cancel buttons in a form dialog's toolbar.
///
/// None of the app's form dialogs styled these, so each inherited whatever the
/// platform default happened to be. On macOS that gave a Save whose label sat
/// in the accent colour on an accent fill — green on green — a Cancel in bare
/// accent text, and a disabled Save that still read as a filled, tappable
/// button.
///
/// These are custom ButtonStyles rather than `.borderedProminent`/`.bordered`
/// for two measured reasons:
///
///  - The system styles wrap the label in an extra accessibility node. With
///    them applied, the audit's own `debt-entry-delete` lookup started matching
///    two elements and threw "Find single matching element". Drawing the
///    capsule here keeps the tree exactly as it was.
///  - `.disabled()` under a system style dims to roughly 30% opacity, which
///    fails the contrast audit. That is what made af8b34c8 drop `.disabled()`
///    from these buttons entirely, leaving them looking permanently enabled.
///    An explicit disabled pairing keeps the control genuinely disabled AND
///    readable.
private enum VDialogButtonMetrics {
    static let horizontalPadding = VSpacing.md
    static let verticalPadding = VSpacing.xs

    /// Deliberately the same green in both schemes, and NOT
    /// `VColors.primaryOnSurface`, which flips to the bright brand green in
    /// dark mode — white on that is the 1.97:1 DEC-012 pairing all over again.
    ///
    /// White on this computes to 7.5:1. #1F7D61 was tried first at a computed
    /// 5.05:1 and the audit still reported "contrast nearly passed" on every
    /// Save: the sampler reads the anti-aliased capsule edge, where the fill is
    /// blended with the page, not the flat centre. Same lesson accentOnSurface
    /// already records — headroom is cheaper than chasing the threshold.
    static let confirmFill = Color(red: 0.090196, green: 0.376471, blue: 0.290196) // #17604A

    /// The disabled fill, and a label with headroom on it in every theme —
    /// see VColors.controlDisabledOnFill.
    static let disabledFill = VColors.groupedBackground
    static let disabledLabel = VColors.controlDisabledOnFill

    /// iOS glass toolbar buttons hug a short label ("Save") almost to a circle.
    static let toolbarExtraHorizontalPadding: CGFloat = VSpacing.xs
    /// macOS: the drawn capsule matches the height of the toolbar's other glass
    /// items (Back, the sync status), not just the label.
    static let macToolbarVerticalPadding: CGFloat = 10
}

/// Inline primary action: white on a green that clears AA without an exemption.
struct VPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VTypography.body)
            // The toolbar can offer less width than the padded label needs and
            // the audit reported "Text clipped" on Contact Support's Done.
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isEnabled ? Color.white : VDialogButtonMetrics.disabledLabel)
            .padding(.horizontal, VDialogButtonMetrics.horizontalPadding)
            .padding(.vertical, VDialogButtonMetrics.verticalPadding)
            .background(isEnabled ? VDialogButtonMetrics.confirmFill : VDialogButtonMetrics.disabledFill)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// A toolbar's confirm action (Save, Apply, a sheet's lone Done): the
/// system's glass toolbar button, with the label in the AA accent green.
///
/// Text only — the toolbar draws the glass capsule, so it matches every other
/// navigation-bar button. An earlier filled green capsule sat inside that
/// glass as a second, uneven capsule and did not belong to the glass design.
/// Still a custom style rather than a system one, for the two reasons above:
/// no extra accessibility node, and a disabled label that stays readable
/// (VColors.controlDisabledOnFill) instead of dimming to ~30%.
struct VToolbarConfirmButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            // The toolbar can offer less width than the label needs; the audit
            // reported "Text clipped" on Contact Support's Done.
            .fixedSize(horizontal: true, vertical: false)
            // A little more room inside the system glass than its default.
            .padding(.horizontal, VDialogButtonMetrics.toolbarExtraHorizontalPadding)
            .foregroundStyle(isEnabled ? VColors.primaryOnSurface : VDialogButtonMetrics.disabledLabel)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A toolbar's cancel action (Cancel, Close): the same glass button with a
/// plain primary-text label.
struct VToolbarCancelButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fixedSize(horizontal: true, vertical: false)
            // A little more room inside the system glass than its default.
            .padding(.horizontal, VDialogButtonMetrics.toolbarExtraHorizontalPadding)
            .foregroundStyle(isEnabled ? VColors.textPrimary : VDialogButtonMetrics.disabledLabel)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#if os(macOS)
/// macOS draws the glass itself. A sheet's footer has no toolbar glass, so a
/// text-only label read as plain text there; and the system button styles
/// either filled the sheet's default action with the accent (white on the
/// light brand green, the 1.97:1 DEC-012 pairing) or, as glass, drew its
/// label white and ignored the green. Same capsule in a window toolbar, whose
/// own glass is hidden by `vDialogToolbarItem()`.
struct VMacGlassDialogButtonStyle: ButtonStyle {
    let isConfirm: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(isConfirm ? .semibold : .regular)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(
                !isEnabled ? VDialogButtonMetrics.disabledLabel
                    : (isConfirm ? VColors.primaryOnSurface : VColors.textPrimary)
            )
            .padding(.horizontal, VDialogButtonMetrics.horizontalPadding)
            .padding(.vertical, VDialogButtonMetrics.macToolbarVerticalPadding)
            .glassEffect(.regular.interactive(), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
#endif

extension View {
    func vDialogConfirmButton() -> some View {
        #if os(macOS)
        buttonStyle(VMacGlassDialogButtonStyle(isConfirm: true))
        #else
        buttonStyle(VToolbarConfirmButtonStyle())
        #endif
    }

    func vDialogCancelButton() -> some View {
        #if os(macOS)
        buttonStyle(VMacGlassDialogButtonStyle(isConfirm: false))
        #else
        buttonStyle(VToolbarCancelButtonStyle())
        #endif
    }

    /// The filled green capsule, for an inline primary action outside a
    /// toolbar — the savings contribution's Add, the paywall's purchase.
    func vPrimaryActionButton() -> some View {
        buttonStyle(VPrimaryActionButtonStyle())
    }
}

extension ToolbarContent {
    /// Put on every ToolbarItem holding a vDialog button. On macOS it hides
    /// the toolbar's own glass so the button's glass capsule is not drawn
    /// inside a second one; on iOS the system glass IS the button.
    func vDialogToolbarItem() -> some ToolbarContent {
        #if os(macOS)
        sharedBackgroundVisibility(.hidden)
        #else
        self
        #endif
    }
}
