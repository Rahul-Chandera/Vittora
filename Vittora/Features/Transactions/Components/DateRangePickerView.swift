import SwiftUI

struct DateRangePickerView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var preset: TransactionFilterViewModel.DatePreset

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            // Preset chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.sm) {
                    ForEach(TransactionFilterViewModel.DatePreset.allCases, id: \.self) { p in
                        Button {
                            preset = p
                            updateDatesForPreset(p)
                        } label: {
                            Text(p.displayName)
                                .font(VTypography.caption1)
                                .foregroundColor(
                                    preset == p ? .white : VColors.textPrimary
                                )
                                .padding(.horizontal, VSpacing.md)
                                .padding(.vertical, VSpacing.sm)
                                .background(
                                    preset == p ? VColors.primary : VColors.secondaryBackground
                                )
                                .cornerRadius(VSpacing.cornerRadiusSM)
                        }
                    }
                }
                .padding(.horizontal, VSpacing.md)
            }

            // Custom date range pickers
            if preset == .custom {
                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text("Custom Range")
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                        .padding(.horizontal, VSpacing.md)

                    VStack(spacing: VSpacing.md) {
                        HStack {
                            Text("From")
                                .font(VTypography.body)
                                .foregroundColor(VColors.textPrimary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { startDate ?? Date.now },
                                    set: { startDate = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                        }
                        .padding(VSpacing.md)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusSM)

                        HStack {
                            Text("To")
                                .font(VTypography.body)
                                .foregroundColor(VColors.textPrimary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { endDate ?? Date.now },
                                    set: { endDate = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                        }
                        .padding(VSpacing.md)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusSM)
                    }
                    .padding(.horizontal, VSpacing.md)
                }
            }
        }
    }

    private func updateDatesForPreset(_ p: TransactionFilterViewModel.DatePreset) {
        var vm = TransactionFilterViewModel()
        vm.applyDatePreset(p)
        startDate = vm.startDate
        endDate = vm.endDate
    }
}

#Preview {
    Form {
        DateRangePickerView(
            startDate: .constant(nil),
            endDate: .constant(nil),
            preset: .constant(.allTime)
        )
    }
}
