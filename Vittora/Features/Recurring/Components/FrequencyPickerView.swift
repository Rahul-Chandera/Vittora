import SwiftUI

struct FrequencyPickerView: View {
    @Binding var selectedFrequency: RecurrenceFrequency
    @State private var customDays: String = "7"

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Frequency")
                .font(VTypography.calloutBold)
                .foregroundColor(VColors.textPrimary)

            VStack(spacing: VSpacing.sm) {
                frequencyButton("Daily", frequency: .daily)
                frequencyButton("Weekly", frequency: .weekly)
                frequencyButton("Bi-weekly", frequency: .biweekly)
                frequencyButton("Monthly", frequency: .monthly)
                frequencyButton("Quarterly", frequency: .quarterly)
                frequencyButton("Yearly", frequency: .yearly)

                // Custom frequency
                HStack(spacing: VSpacing.md) {
                    Text("Custom (days)")
                        .font(VTypography.callout)
                        .foregroundColor(VColors.textPrimary)

                    Spacer()

                    TextField("Days", text: $customDays)
                        .font(VTypography.callout)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: customDays) { oldValue, newValue in
                            if let days = Int(newValue), days > 0 {
                                selectedFrequency = .custom(days: days)
                            }
                        }
                }
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusMD)
            }
        }
    }

    private func frequencyButton(_ label: String, frequency: RecurrenceFrequency) -> some View {
        Button(action: {
            selectedFrequency = frequency
        }) {
            HStack {
                Text(label)
                    .font(VTypography.callout)
                    .foregroundColor(isSelected(frequency) ? .white : VColors.textPrimary)

                Spacer()

                if isSelected(frequency) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(VSpacing.md)
            .background(isSelected(frequency) ? VColors.primary : VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusMD)
        }
    }

    private func isSelected(_ frequency: RecurrenceFrequency) -> Bool {
        switch (selectedFrequency, frequency) {
        case (.daily, .daily),
             (.weekly, .weekly),
             (.biweekly, .biweekly),
             (.monthly, .monthly),
             (.quarterly, .quarterly),
             (.yearly, .yearly):
            return true
        default:
            return false
        }
    }
}

#Preview {
    @State var selectedFrequency: RecurrenceFrequency = .monthly
    return FrequencyPickerView(selectedFrequency: $selectedFrequency)
        .padding(VSpacing.lg)
        .background(VColors.background)
}
