import SwiftUI
import Charts

struct SpendingTrendsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SpendingTrendsViewModel?
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

                    groupingSelector(vm)

                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else if vm.dataPoints.isEmpty {
                        emptyState
                    } else {
                        statsRow(vm)
                        chartSection(vm)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Spending Trends"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil {
                guard let repo = dependencies.transactionRepository else { return }
                let useCase = SpendingTrendsUseCase(transactionRepository: repo)
                vm = SpendingTrendsViewModel(useCase: useCase)
                await vm?.load()
            }
        }
    }

    @ViewBuilder
    private func groupingSelector(_ vm: SpendingTrendsViewModel) -> some View {
        Picker(String(localized: "Grouping"), selection: Binding(
            get: { vm.grouping },
            set: { g in Task { await vm.applyGrouping(g) } }
        )) {
            ForEach(TrendGrouping.allCases, id: \.self) { g in
                Text(g.displayName).tag(g)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func statsRow(_ vm: SpendingTrendsViewModel) -> some View {
        HStack(spacing: VSpacing.md) {
            statCard(label: String(localized: "Total"), amount: vm.totalAmount)
            statCard(label: String(localized: "Average"), amount: vm.averageAmount)
            statCard(label: String(localized: "Peak"), amount: vm.peakAmount)
        }
    }

    private func statCard(label: String, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(label)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
            Text(formattedAmount(amount))
                .font(VTypography.amountSmall)
                .foregroundColor(VColors.textPrimary)
        }
        .padding(VSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }

    @ViewBuilder
    private func chartSection(_ vm: SpendingTrendsViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Trend"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            TrendAreaChart(dataPoints: vm.dataPoints, color: VColors.expense)
                .frame(height: 220)
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(VColors.textTertiary)
            Text(String(localized: "No data for selected period"))
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    NavigationStack {
        SpendingTrendsView()
    }
}
