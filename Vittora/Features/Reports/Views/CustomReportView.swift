import SwiftUI

struct CustomReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    @State private var vm: CustomReportViewModel?
    @State private var selectedPreset: DateRangePreset = .thisMonth
    @State private var customStart: Date = .now
    @State private var customEnd: Date = .now

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm = vm {
                    configSection(vm)

                    Button(String(localized: "Generate Report")) {
                        Task { await vm.generate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VColors.primary)
                    .frame(maxWidth: .infinity)

                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else if let result = vm.result {
                        resultSection(result)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Custom Report"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil {
                guard let txRepo = dependencies.transactionRepository,
                      let catRepo = dependencies.categoryRepository,
                      let accRepo = dependencies.accountRepository,
                      let payeeRepo = dependencies.payeeRepository else { return }
                let useCase = CustomReportUseCase(
                    transactionRepository: txRepo,
                    categoryRepository: catRepo,
                    accountRepository: accRepo,
                    payeeRepository: payeeRepo
                )
                vm = CustomReportViewModel(useCase: useCase)
                await vm?.generate()
            }
        }
        .errorAlert(message: customReportErrorBinding)
    }

    @ViewBuilder
    private func configSection(_ vm: CustomReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Date Range"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            DateRangeSelectorView(
                selectedPreset: $selectedPreset,
                customStart: $customStart,
                customEnd: $customEnd,
                onApply: { range in vm.dateRange = range }
            )

            Divider()

            Text(String(localized: "Group By"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            Picker(String(localized: "Grouping"), selection: Binding(
                get: { vm.grouping },
                set: { vm.grouping = $0 }
            )) {
                ForEach(ReportGrouping.allCases, id: \.self) { g in
                    Text(g.displayName).tag(g)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            Text(String(localized: "Transaction Type"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            Picker(String(localized: "Type"), selection: Binding(
                get: { vm.selectedType },
                set: { vm.selectedType = $0 }
            )) {
                Text(String(localized: "All")).tag(Optional<TransactionType>.none)
                Text(String(localized: "Expenses")).tag(Optional(TransactionType.expense))
                Text(String(localized: "Income")).tag(Optional(TransactionType.income))
            }
            .pickerStyle(.segmented)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    @ViewBuilder
    private func resultSection(_ result: CustomReportResult) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            HStack {
                Text(String(localized: "Results"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Text(String(localized: "\(result.rows.count) groups"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textTertiary)
            }

            if result.rows.isEmpty {
                Text(String(localized: "No data for selected filters"))
                    .font(VTypography.body)
                    .foregroundColor(VColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
            } else {
                VStack(spacing: VSpacing.md) {
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                        ReportSummaryRow(
                            label: row.label,
                            amount: row.amount,
                            percentage: row.percentage,
                            color: VColors.categoryColors[index % VColors.categoryColors.count],
                            count: row.count
                        )
                    }
                }
                .padding(VSpacing.cardPadding)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)

                totalRow(result.total)
            }
        }
    }

    private func totalRow(_ total: Decimal) -> some View {
        HStack {
            Text(String(localized: "Total"))
                .font(VTypography.bodyBold)
                .foregroundColor(VColors.textPrimary)
            Spacer()
            Text(formattedAmount(total))
                .font(VTypography.amountSmall)
                .foregroundColor(VColors.textPrimary)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencySymbol)0.00"
    }

    private var customReportErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        CustomReportView()
    }
}
