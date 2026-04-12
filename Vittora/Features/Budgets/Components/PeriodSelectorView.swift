import SwiftUI

struct PeriodSelectorView: View {
    @Binding var selectedPeriod: BudgetPeriod

    var body: some View {
        #if os(iOS)
        Picker("Period", selection: $selectedPeriod) {
            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                Text(period.rawValue.capitalized).tag(period)
            }
        }
        .pickerStyle(.segmented)
        #else
        HStack(spacing: VSpacing.md) {
            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue.capitalized)
                        .font(VTypography.caption1)
                        .foregroundColor(selectedPeriod == period ? VColors.primary : VColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(VSpacing.sm)
                        .background(selectedPeriod == period ? VColors.primary.opacity(0.1) : VColors.tertiaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusSM)
                }
                .buttonStyle(.plain)
            }
        }
        #endif
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Select Period")
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)

                PeriodSelectorView(selectedPeriod: .constant(.monthly))
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
