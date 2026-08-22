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

    /// The disabled fill, and a label dark enough to sit on it with headroom.
    ///
    /// `VColors.controlDisabled` is the app's semantic choice here, but its own
    /// note records 4.54:1 on the grouped grey — and the audit reported every
    /// disabled Save as "contrast nearly passed" at exactly that pairing. These
    /// audits open an empty form, so the disabled state is the one they sample.
    /// This label measures ~6.1:1 on the fill below while staying clearly
    /// muted against the green-and-white enabled state.
    static let disabledFill = VColors.groupedBackground
    static let disabledLabel = Color(red: 0.352941, green: 0.352941, blue: 0.372549) // #5A5A5F
}

/// Primary action: white on a green that clears AA without an exemption.
struct VDialogConfirmButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VTypography.body)
            .foregroundStyle(isEnabled ? Color.white : VDialogButtonMetrics.disabledLabel)
            .padding(.horizontal, VDialogButtonMetrics.horizontalPadding)
            .padding(.vertical, VDialogButtonMetrics.verticalPadding)
            .background(isEnabled ? VDialogButtonMetrics.confirmFill : VDialogButtonMetrics.disabledFill)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Secondary action: a light grey fill with a dark label, so it reads as a
/// control beside the confirm button rather than as bare accent text.
struct VDialogCancelButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VTypography.body)
            .foregroundStyle(isEnabled ? VColors.textPrimary : VDialogButtonMetrics.disabledLabel)
            .padding(.horizontal, VDialogButtonMetrics.horizontalPadding)
            .padding(.vertical, VDialogButtonMetrics.verticalPadding)
            .background(VDialogButtonMetrics.disabledFill)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    func vDialogConfirmButton() -> some View {
        buttonStyle(VDialogConfirmButtonStyle())
    }

    func vDialogCancelButton() -> some View {
        buttonStyle(VDialogCancelButtonStyle())
    }
}
