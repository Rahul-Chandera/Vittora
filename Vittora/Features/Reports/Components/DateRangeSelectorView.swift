import SwiftUI

enum DateRangePreset: String, CaseIterable, Sendable {
    case thisMonth, lastMonth, thisQuarter, yearToDate, lastYear, custom

    var displayName: String {
        switch self {
        case .thisMonth:    return String(localized: "This Month")
        case .lastMonth:    return String(localized: "Last Month")
        case .thisQuarter:  return String(localized: "This Quarter")
        case .yearToDate:   return String(localized: "Year to Date")
        case .lastYear:     return String(localized: "Last Year")
        case .custom:       return String(localized: "Custom")
        }
    }

    func dateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date.now
        switch self {
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return start...now
        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            let end = calendar.date(byAdding: .second, value: -1, to: thisMonthStart) ?? now
            return start...end
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            let start = calendar.date(from: components) ?? now
            return start...now
        case .yearToDate:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components) ?? now
            return start...now
        case .lastYear:
            var startComponents = calendar.dateComponents([.year], from: now)
            startComponents.year = (startComponents.year ?? 2024) - 1
            startComponents.month = 1
            startComponents.day = 1
            let start = calendar.date(from: startComponents) ?? now
            var endComponents = startComponents
            endComponents.month = 12
            endComponents.day = 31
            let end = calendar.date(from: endComponents) ?? now
            return start...end
        case .custom:
            return nil
        }
    }
}

struct DateRangeSelectorView: View {
    @Binding var selectedPreset: DateRangePreset
    @Binding var customStart: Date
    @Binding var customEnd: Date
    let onApply: (ClosedRange<Date>?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.sm) {
                    ForEach(DateRangePreset.allCases, id: \.self) { preset in
                        presetChip(preset)
                    }
                }
                .padding(.horizontal, VSpacing.xxs)
            }

            if selectedPreset == .custom {
                HStack(spacing: VSpacing.md) {
                    DatePicker(
                        String(localized: "From"),
                        selection: $customStart,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()

                    Text("–")
                        .foregroundColor(VColors.textSecondary)

                    DatePicker(
                        String(localized: "To"),
                        selection: $customEnd,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()

                    Button(String(localized: "Apply")) {
                        onApply(customStart...customEnd)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VColors.primary)
                }
            }
        }
    }

    private func presetChip(_ preset: DateRangePreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            selectedPreset = preset
            if preset != .custom {
                onApply(preset.dateRange())
            }
        } label: {
            Text(preset.displayName)
                .font(VTypography.caption1)
                .foregroundColor(isSelected ? .white : VColors.textPrimary)
                .padding(.horizontal, VSpacing.md)
                .padding(.vertical, VSpacing.sm)
                .background(isSelected ? VColors.primary : VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusPill)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DateRangeSelectorView(
        selectedPreset: .constant(.thisMonth),
        customStart: .constant(.now),
        customEnd: .constant(.now),
        onApply: { _ in }
    )
    .padding()
}
