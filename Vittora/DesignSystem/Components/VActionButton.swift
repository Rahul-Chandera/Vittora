import SwiftUI

/// A customizable action button with Primary, Secondary, and Destructive styles.
/// Supports loading state, full width layout, and haptic feedback.
struct VActionButton: View {
    let label: String
    let action: () -> Void
    let style: ButtonStyle
    let size: ButtonSize
    let isFullWidth: Bool
    let isLoading: Bool
    let isEnabled: Bool
    let hapticFeedback: Bool

    enum ButtonStyle {
        case primary
        case secondary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary:
                return VColors.primary
            case .secondary:
                return VColors.secondaryBackground
            case .destructive:
                return VColors.expense
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary:
                return VColors.textPrimary
            }
        }

        var borderColor: Color {
            switch self {
            case .primary, .destructive:
                return .clear
            case .secondary:
                return VColors.textTertiary
            }
        }
    }

    enum ButtonSize {
        case small
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .small:
                return 36
            case .regular:
                return 44
            case .large:
                return 54
            }
        }

        var font: Font {
            switch self {
            case .small:
                return VTypography.caption1Bold
            case .regular:
                return VTypography.calloutBold
            case .large:
                return VTypography.bodyBold
            }
        }
    }

    init(
        _ label: String,
        action: @escaping () -> Void,
        style: ButtonStyle = .primary,
        size: ButtonSize = .regular,
        fullWidth: Bool = false,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        hapticFeedback: Bool = true
    ) {
        self.label = label
        self.action = action
        self.style = style
        self.size = size
        self.isFullWidth = fullWidth
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.hapticFeedback = hapticFeedback
    }

    var body: some View {
        Button(action: {
            if hapticFeedback {
                HapticFeedback.light()
            }
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                    .fill(style.backgroundColor)
                    .opacity(isEnabled ? 1 : 0.5)

                HStack(spacing: VSpacing.md) {
                    if isLoading {
                        ProgressView()
                            .tint(style.foregroundColor)
                    }

                    Text(label)
                        .font(size.font)
                        .foregroundColor(style.foregroundColor)
                        .opacity(isLoading ? 0.7 : 1)

                    if isLoading {
                        Spacer()
                            .frame(width: 0)
                    }
                }
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .frame(height: size.height)
            }
        }
        .disabled(!isEnabled || isLoading)
        .if(style == .secondary) { view in
            view.overlay(
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                    .stroke(style.borderColor, lineWidth: 1)
            )
        }
    }
}

// MARK: - Convenience Initializers
extension VActionButton {
    init(
        _ label: String,
        action: @escaping () -> Void,
        size: ButtonSize = .regular,
        fullWidth: Bool = false
    ) {
        self.init(label, action: action, style: .primary, size: size, fullWidth: fullWidth)
    }
}

// MARK: - Haptic Feedback Helper
enum HapticFeedback {
    static func light() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }

    static func medium() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
    }

    static func heavy() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Text("Primary Button")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VActionButton(
                    "Continue",
                    action: {},
                    fullWidth: true
                )

                VActionButton(
                    "Loading...",
                    action: {},
                    fullWidth: true,
                    isLoading: true
                )

                VActionButton(
                    "Disabled",
                    action: {},
                    fullWidth: true,
                    isEnabled: false
                )
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Text("Secondary Button")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VActionButton(
                    "Cancel",
                    action: {},
                    style: .secondary,
                    fullWidth: true
                )
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Text("Destructive Button")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VActionButton(
                    "Delete",
                    action: {},
                    style: .destructive,
                    fullWidth: true
                )
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Text("Various Sizes")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VActionButton(
                    "Small",
                    action: {},
                    size: .small,
                    fullWidth: true
                )

                VActionButton(
                    "Regular",
                    action: {},
                    size: .regular,
                    fullWidth: true
                )

                VActionButton(
                    "Large",
                    action: {},
                    size: .large,
                    fullWidth: true
                )
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
