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
        // The native segmented control, same as iOS at regular width.
        //
        // This was a hand-rolled row of buttons whose selected state was
        // VColors.primary at 10% opacity over VColors.tertiaryBackground. On
        // macOS 26 that background resolves to #FFFFFF, so the selection was a
        // barely-there green wash on white and you could not tell which period
        // was active. The platform control draws a proper selection indicator
        // and is less code than getting a custom one right.
        periodPicker
            .pickerStyle(.segmented)
            .labelsHidden()
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
