import SwiftUI

/// A versatile card container with material background, subtle shadow, and configurable styling.
/// Provides a clean, Apple-like appearance for grouping content.
struct VCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = VSpacing.cardPadding
    var cornerRadius: CGFloat = VSpacing.cornerRadiusCard
    var shadow: VSpacing.Shadow = .subtle
    var backgroundColor: Color = VColors.secondaryBackground

    init(
        padding: CGFloat = VSpacing.cardPadding,
        cornerRadius: CGFloat = VSpacing.cornerRadiusCard,
        shadow: VSpacing.Shadow = .subtle,
        backgroundColor: Color = VColors.secondaryBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow.color.opacity(shadow.opacity),
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

// MARK: - View Modifier
extension View {
    /// Apply card styling with customizable padding, corner radius, and shadow.
    func vCard(
        padding: CGFloat = VSpacing.cardPadding,
        cornerRadius: CGFloat = VSpacing.cornerRadiusCard,
        shadow: VSpacing.Shadow = .subtle,
        backgroundColor: Color = VColors.secondaryBackground
    ) -> some View {
        self
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow.color.opacity(shadow.opacity),
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Standard Card")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)
                Text("This is a card with default styling.")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }
        }

        VCard(padding: VSpacing.xl, shadow: .medium) {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Elevated Card")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)
                Text("This card has more padding and a stronger shadow.")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }
        }

        VCard(backgroundColor: VColors.tertiary Background) {
            HStack(spacing: VSpacing.md) {
                Image(systemName: VIcons.Actions.search)
                    .foregroundColor(VColors.primary)
                Text("Searchable card")
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                Spacer()
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
