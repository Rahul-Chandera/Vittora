import SwiftUI

/// A compact stat card displaying a label, value, and optional trend indicator.
/// Ideal for dashboard grids showing key metrics.
struct VStatCard: View {
    let label: String
    let value: Decimal
    let currencyCode: String
    let trend: Trend?
    let backgroundColor: Color
    let accentColor: Color

    enum Trend {
        case up(percentage: Double)
        case down(percentage: Double)

        var icon: String {
            switch self {
            case .up:
                return "arrow.up.right"
            case .down:
                return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .up:
                return VColors.income
            case .down:
                return VColors.expense
            }
        }

        var percentage: Double {
            switch self {
            case .up(let percentage), .down(let percentage):
                return percentage
            }
        }
    }

    init(
        label: String,
        value: Decimal,
        currencyCode: String = "USD",
        trend: Trend? = nil,
        backgroundColor: Color = VColors.secondaryBackground,
        accentColor: Color = VColors.primary
    ) {
        self.label = label
        self.value = value
        self.currencyCode = currencyCode
        self.trend = trend
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
    }

    var body: some View {
        VCard(
            padding: VSpacing.md,
            cornerRadius: VSpacing.cornerRadiusCard,
            shadow: .subtle,
            backgroundColor: backgroundColor
        ) {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(label)
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)

                        VAmountText(value, currencyCode: currencyCode, size: .medium)
                    }

                    Spacer()

                    if let trend = trend {
                        VStack(alignment: .trailing, spacing: VSpacing.xs) {
                            HStack(spacing: VSpacing.xs) {
                                Image(systemName: trend.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(Int(trend.percentage))%")
                                    .font(VTypography.caption2Bold)
                            }
                            .foregroundColor(trend.color)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Stat Cards Grid")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)

            HStack(spacing: VSpacing.md) {
                VStatCard(
                    label: "Total Income",
                    value: 4500,
                    trend: .up(percentage: 12.5),
                    backgroundColor: VColors.income.opacity(0.1),
                    accentColor: VColors.income
                )

                VStatCard(
                    label: "Total Spent",
                    value: 2150,
                    trend: .down(percentage: 3.2),
                    backgroundColor: VColors.expense.opacity(0.1),
                    accentColor: VColors.expense
                )
            }
        }

        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Without Trend")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)

            HStack(spacing: VSpacing.md) {
                VStatCard(
                    label: "Savings",
                    value: 8750,
                    accentColor: VColors.savings
                )

                VStatCard(
                    label: "Budget Left",
                    value: 1250,
                    accentColor: .teal
                )
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
