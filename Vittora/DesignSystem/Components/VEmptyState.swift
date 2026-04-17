import SwiftUI

/// An empty state view showing a large icon, title, subtitle, and optional action button.
/// Used when no data is available or no results are found.
struct VEmptyState: View {
    let iconName: String
    let title: String
    let subtitle: String?
    let actionLabel: String?
    let actionHandler: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = icon
        self.title = title
        self.subtitle = subtitle
        self.actionLabel = actionLabel
        self.actionHandler = action
    }

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            VStack(spacing: VSpacing.md) {
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(VColors.textTertiary)
                    .padding(VSpacing.lg)
                    .background(VColors.tertiaryBackground)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(spacing: VSpacing.sm) {
                    Text(title)
                        .font(VTypography.title2)
                        .foregroundColor(VColors.textPrimary)
                        .multilineTextAlignment(.center)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(VTypography.body)
                            .foregroundColor(VColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            if let actionLabel = actionLabel, let actionHandler = actionHandler {
                VActionButton(actionLabel, action: actionHandler)
                    .padding(.horizontal, VSpacing.screenPadding)
            }

            Spacer()
        }
        .padding(VSpacing.screenPadding)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.xl) {
        VEmptyState(
            icon: VIcons.Actions.search,
            title: "No Transactions",
            subtitle: "Start by adding your first transaction to get started.",
            actionLabel: "Add Transaction",
            action: {}
        )
    }
    .background(VColors.background)
}
