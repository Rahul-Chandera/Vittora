import SwiftUI
import VittoraCore

struct TaxDisclaimerView: View {
    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.sm) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.caption)
                .foregroundStyle(VColors.textPrimary)
                .padding(.top, 2)

            Text(TaxDisclaimer.text)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(VColors.textTertiary.opacity(0.35), lineWidth: 1)
        )
    }
}
