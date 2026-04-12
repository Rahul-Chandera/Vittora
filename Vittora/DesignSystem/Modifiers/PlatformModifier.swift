import SwiftUI

/// A modifier that applies platform-specific padding for iPhone, iPad, and Mac.
/// Provides ergonomic spacing based on device type and interface idiom.
struct PlatformModifier: ViewModifier {
    let horizontal: CGFloat?
    let vertical: CGFloat?

    #if os(macOS)
    let horizontalDefault = VSpacing.xl
    let verticalDefault = VSpacing.lg
    #else
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var horizontalDefault: CGFloat {
        horizontalSizeClass == .regular ? VSpacing.xl : VSpacing.lg
    }

    var verticalDefault: CGFloat {
        horizontalSizeClass == .regular ? VSpacing.lg : VSpacing.md
    }
    #endif

    init(horizontal: CGFloat? = nil, vertical: CGFloat? = nil) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal ?? horizontalDefault)
            .padding(.vertical, vertical ?? verticalDefault)
    }
}

// MARK: - Preset Padding Modifiers
struct AdaptiveScreenPaddingModifier: ViewModifier {
    #if os(macOS)
    let padding = VSpacing.xl
    #else
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var padding: CGFloat {
        horizontalSizeClass == .regular ? VSpacing.xl : VSpacing.lg
    }
    #endif

    func body(content: Content) -> some View {
        content
            .padding(padding)
    }
}

extension View {
    /// Apply adaptive padding based on platform (iPhone/iPad/Mac) and interface idiom.
    func adaptivePadding(
        horizontal: CGFloat? = nil,
        vertical: CGFloat? = nil
    ) -> some View {
        modifier(PlatformModifier(horizontal: horizontal, vertical: vertical))
    }

    /// Apply adaptive screen-edge padding.
    func adaptiveScreenPadding() -> some View {
        modifier(AdaptiveScreenPaddingModifier())
    }

    /// Apply different padding for iPhone vs iPad layouts.
    func responsivePadding(
        phone: EdgeInsets,
        tablet: EdgeInsets
    ) -> some View {
        #if os(macOS)
        self.padding(tablet)
        #else
        self.padding(phone)
        #endif
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Adaptive Padding Example")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)
                    .adaptivePadding()

                Text("This content uses platform-aware padding that adjusts based on device type (iPhone, iPad, or Mac).")
                    .font(VTypography.body)
                    .foregroundColor(VColors.textSecondary)
            }
        }
        .adaptiveScreenPadding()

        VStack(spacing: VSpacing.md) {
            Text("Platform Information")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)

            #if os(iOS)
            Text("Running on iOS")
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
            #elseif os(macOS)
            Text("Running on macOS")
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
            #endif
        }
        .adaptiveScreenPadding()

        Spacer()
    }
    .background(VColors.background)
}
