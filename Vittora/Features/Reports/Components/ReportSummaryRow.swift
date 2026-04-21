import SwiftUI

struct ReportSummaryRow: View {
    let label: String
    let amount: Decimal
    let percentage: Double
    let color: Color
    let count: Int
    var currencyCode: String = "USD"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: VSpacing.sm) {
            HStack {
                HStack(spacing: VSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)

                    Text(label)
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textPrimary)
                        .adaptiveLineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                    Text(formattedAmount(amount))
                        .font(VTypography.caption1Bold)
                        .foregroundColor(VColors.textPrimary)

                    Text(String(format: "%.1f%%", percentage))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(VColors.tertiaryBackground)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 4)
                        .animation(reduceMotion ? .none : .easeOut(duration: VSpacing.animationStandard), value: percentage)
                }
            }
            .frame(height: 4)
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
}

#Preview {
    ReportSummaryRow(
        label: "Food & Dining",
        amount: 450.50,
        percentage: 32.5,
        color: .blue,
        count: 12
    )
    .padding()
}
