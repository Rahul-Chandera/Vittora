import SwiftUI

struct ReportCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD))

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(title)
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)

                Text(subtitle)
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

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
