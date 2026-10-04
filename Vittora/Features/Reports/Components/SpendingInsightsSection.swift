import SwiftUI
import VittoraCore

/// Dismissible observations drawn from the user's own records (M3.6.4 / M3.6.5).
///
/// Mirrors `IndiaComplianceTipsSection` deliberately: same card shape, same 44pt dismiss
/// target, same discipline that the body states a fact rather than issuing an instruction.
struct SpendingInsightsSection: View {
    let insights: [SpendingInsight]
    let onDismiss: (SpendingInsight) -> Void

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Worth a look"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                ForEach(insights) { insight in
                    insightCard(insight)
                }
            }
            .accessibilityIdentifier("spending-insights")
        }
    }

    private func insightCard(_ insight: SpendingInsight) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .top, spacing: VSpacing.sm) {
                Image(systemName: symbol(for: insight))
                    .foregroundStyle(VColors.textPrimary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    // textSecondary, not tertiary — card metadata has to clear AA on the
                    // secondaryGroupedBackground surface under the accessibility audit.
                    Text(insight.detail)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss(insight)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(VColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Dismiss insight"))
            }

            Text(String(localized: "Based on your own records for the last few months, not a recommendation."))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityIdentifier("spending-insight-\(insight.id)")
    }

    private func symbol(for insight: SpendingInsight) -> String {
        switch insight.kind {
        case .anomaly:
            return "chart.line.uptrend.xyaxis"
        case .budget(let observation):
            switch observation.kind {
            case .consistentlyOverSpent: return "exclamationmark.triangle"
            case .unused: return "tray"
            case .consistentlyUnderSpent: return "arrow.down.circle"
            }
        }
    }
}
