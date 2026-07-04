import SwiftUI
import VittoraCore

/// Prominent US-only honesty label (M1 / DEC-010): federal estimates exclude state tax.
struct USTaxFederalEstimateLabel: View {
    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(VColors.primary)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(TaxDisclaimer.usFederalEstimateLabel)
                .font(VTypography.caption1Bold)
                .foregroundStyle(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.primary.opacity(0.08))
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(VColors.primary.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("us-tax-federal-estimate-label")
    }
}
