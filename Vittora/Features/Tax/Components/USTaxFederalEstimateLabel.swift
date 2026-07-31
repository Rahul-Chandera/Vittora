import SwiftUI
import VittoraCore

/// Prominent US-only honesty label (M1 / DEC-010): federal estimates exclude state tax.
struct USTaxFederalEstimateLabel: View {
    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                // Accents clear AA on pure black/white, not on secondary cards or
                // tinted chips — use textPrimary for chrome on those surfaces.
                .foregroundStyle(VColors.textPrimary)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(TaxDisclaimer.usFederalEstimateLabel)
                .font(VTypography.caption1Bold)
                .foregroundStyle(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(VSpacing.cardPadding)
        // tertiary sits on secondary cards with a visible edge; matching
        // secondaryBackground made the chip disappear into the parent card.
        .background(VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(VColors.textTertiary.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("us-tax-federal-estimate-label")
    }
}
