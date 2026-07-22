import SwiftUI
import VittoraCore

struct IndiaComplianceTipsSection: View {
    let tips: [IndiaComplianceTip]
    let onDismiss: (IndiaComplianceTip) -> Void

    var body: some View {
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Compliance tips"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                ForEach(tips) { tip in
                    tipCard(tip)
                }
            }
            .accessibilityIdentifier("india-compliance-tips")
        }
    }

    private func tipCard(_ tip: IndiaComplianceTip) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .top, spacing: VSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(VColors.primary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(tip.detail)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tip.statutorySource + " · " + tip.assessmentYear)
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textTertiary)
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss(tip)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VColors.textTertiary)
                }
                .accessibilityLabel(String(localized: "Dismiss tip"))
            }

            TaxDisclaimerView()
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityIdentifier("india-compliance-tip-\(tip.ruleID.rawValue)")
    }
}
