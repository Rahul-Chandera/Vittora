import SwiftUI

struct TaxDisclaimerView: View {
    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.sm) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.caption)
                .foregroundStyle(VColors.warning)
                .padding(.top, 2)

            Text(TaxDisclaimer.text)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.warning.opacity(0.10))
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(VColors.warning.opacity(0.25), lineWidth: 1)
        )
    }
}
