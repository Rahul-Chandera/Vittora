import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: CategoryBreakdownViewModel?
    @State private var selectedCategoryID: UUID?
    @State private var selectedPreset: DateRangePreset = .thisMonth
    @State private var customStart: Date = .now
    @State private var customEnd: Date = .now

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm = vm {
                    DateRangeSelectorView(
                        selectedPreset: $selectedPreset,
                        customStart: $customStart,
                        customEnd: $customEnd,
                        onApply: { range in
                            Task { await vm.applyDateRange(range) }
                        }
                    )

                    typeSelector(vm)

                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else if vm.breakdowns.isEmpty {
                        emptyState
                    } else {
                        chartAndLegend(vm)
                        breakdownList(vm)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Category Breakdown"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil {
                guard let txRepo = dependencies.transactionRepository,
                      let catRepo = dependencies.categoryRepository else { return }
                let useCase = CategoryBreakdownUseCase(
                    transactionRepository: txRepo,
                    categoryRepository: catRepo
                )
                vm = CategoryBreakdownViewModel(useCase: useCase)
                await vm?.load()
            }
        }
        .errorAlert(message: categoryBreakdownErrorBinding)
    }

    @ViewBuilder
    private func typeSelector(_ vm: CategoryBreakdownViewModel) -> some View {
        Picker(String(localized: "Type"), selection: Binding(
            get: { vm.selectedType },
            set: { type in Task { await vm.applyType(type) } }
        )) {
            Text(String(localized: "Expenses")).tag(TransactionType.expense)
            Text(String(localized: "Income")).tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func chartAndLegend(_ vm: CategoryBreakdownViewModel) -> some View {
        HStack(alignment: .center, spacing: VSpacing.xl) {
            CategoryDonutChart(
                breakdowns: vm.breakdowns,
                selectedCategory: $selectedCategoryID,
                currencyCode: currencyCode
            )
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: VSpacing.sm) {
                ForEach(Array(vm.breakdowns.prefix(5).enumerated()), id: \.offset) { index, item in
                    Button {
                        selectedCategoryID = selectedCategoryID == item.id ? nil : item.id
                    } label: {
                        HStack(spacing: VSpacing.sm) {
                            Circle()
                                .fill(VColors.categoryColors[index % VColors.categoryColors.count])
                                .frame(width: 8, height: 8)
                            Text(item.category.name)
                                .font(VTypography.caption2)
                                .foregroundColor(VColors.textPrimary)
                                .adaptiveLineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", item.percentage))
                                .font(VTypography.caption2Bold)
                                .foregroundColor(VColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    @ViewBuilder
    private func breakdownList(_ vm: CategoryBreakdownViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "All Categories"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            VStack(spacing: VSpacing.md) {
                ForEach(Array(vm.breakdowns.enumerated()), id: \.offset) { index, item in
                    ReportSummaryRow(
                        label: item.category.name,
                        amount: item.amount,
                        percentage: item.percentage,
                        color: VColors.categoryColors[index % VColors.categoryColors.count],
                        count: item.transactionCount,
                        currencyCode: currencyCode
                    )
                }
            }
            .padding(VSpacing.cardPadding)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(VColors.textTertiary)
            Text(String(localized: "No data for selected period"))
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }

    private var categoryBreakdownErrorBinding: Binding<String?> {
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
        CategoryBreakdownView()
    }
}
