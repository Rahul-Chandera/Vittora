import SwiftUI
import VittoraCore

struct ReportCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: icon)
                .font(VTypography.title3)
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(title)
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)
                    .adaptiveLineLimit(2)
                    .adaptiveMinimumScaleFactor(0.8)

                Text(subtitle)
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                    .adaptiveLineLimit(2)
                    .adaptiveMinimumScaleFactor(0.8)
            }

            Spacer(minLength: VSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(VColors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }
}

#Preview {
    ReportCardView(
        title: "Monthly Overview",
        subtitle: "Income vs expenses over 12 months",
        icon: "chart.bar.fill",
        color: .blue
    )
    .padding()
}
