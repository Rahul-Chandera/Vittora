import SwiftUI
import VittoraCore

struct PeriodSelectorView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedPeriod: BudgetPeriod

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            periodPicker.pickerStyle(.menu)
        } else {
            periodPicker.pickerStyle(.segmented)
        }
        #else
        HStack(spacing: VSpacing.md) {
            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.displayName)
                        .font(VTypography.caption1)
                        .foregroundColor(selectedPeriod == period ? VColors.primaryOnSurface : VColors.textSecondary)
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

    private var periodPicker: some View {
        Picker(String(localized: "Period"), selection: $selectedPeriod) {
            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
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
