import SwiftUI
import Charts

struct CashFlowReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: MonthlyOverviewViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else {
                        cashFlowSummary(vm)
                        cashFlowChart(vm)
                        cashFlowList(vm)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Cash Flow"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil, let repo = dependencies.transactionRepository else { return }
            let useCase = MonthlyOverviewUseCase(transactionRepository: repo)
            vm = MonthlyOverviewViewModel(useCase: useCase)
            await vm?.load()
        }
        .errorAlert(message: cashFlowReportErrorBinding)
    }

    // MARK: - Summary Card

    private func cashFlowSummary(_ vm: MonthlyOverviewViewModel) -> some View {
        let surplusMonths = vm.monthlyData.filter { $0.net >= 0 }.count
        let deficitMonths = vm.monthlyData.filter { $0.net < 0 }.count
        let avgNet = vm.monthlyData.isEmpty ? Decimal(0)
            : vm.netSavings / Decimal(vm.monthlyData.count)

        return VCard {
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Avg/Month"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(avgNet >= 0
                         ? "+\(avgNet.formatted(.currency(code: currencyCode)))"
                         : "-\(abs(avgNet).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.bodyBold)
                        .foregroundStyle(avgNet >= 0 ? VColors.income : VColors.expense)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("\(surplusMonths)")
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.income)
                    Text(String(localized: "Surplus"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text("\(deficitMonths)")
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.expense)
                    Text(String(localized: "Deficit"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Cash Flow Bar Chart

    private func cashFlowChart(_ vm: MonthlyOverviewViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Monthly Net Cash Flow"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(VColors.textTertiary)

                    ForEach(vm.monthlyData) { data in
                        BarMark(
                            x: .value("Month", data.month, unit: .month),
                            y: .value(String(localized: "Net"), data.net)
                        )
                        .foregroundStyle(data.net >= 0 ? VColors.income : VColors.expense)
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityChartDescriptor(
                    MonthlyNetCashFlowChartDescriptor(
                        data: vm.monthlyData,
                        currencyCode: currencyCode
                    )
                )
                .frame(height: 220)

                HStack(spacing: VSpacing.lg) {
                    Label(String(localized: "Surplus"), systemImage: "square.fill")
                        .foregroundStyle(VColors.income)
                        .font(VTypography.caption1)
                    Label(String(localized: "Deficit"), systemImage: "square.fill")
                        .foregroundStyle(VColors.expense)
                        .font(VTypography.caption1)
                }
            }
        }
    }

    // MARK: - Monthly Net List

    private func cashFlowList(_ vm: MonthlyOverviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Month-by-Month"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(vm.monthlyData.reversed()) { data in
                HStack(spacing: VSpacing.md) {
                    Text(data.month.formatted(.dateTime.month(.wide)))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textPrimary)
                        .frame(width: 90, alignment: .leading)

                    Spacer()

                    // Flow bar
                    let maxNet = vm.monthlyData.map { abs($0.net) }.max() ?? 1
                    let fraction = maxNet > 0 ? Double(truncating: (abs(data.net) / maxNet) as NSDecimalNumber) : 0
                    GeometryReader { geo in
                        let barWidth = geo.size.width * CGFloat(fraction)
                        ZStack(alignment: data.net >= 0 ? .leading : .trailing) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(VColors.secondaryBackground)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(data.net >= 0 ? VColors.income : VColors.expense)
                                .frame(width: max(barWidth, 4), height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(data.net >= 0
                         ? "+\(data.net.formatted(.currency(code: currencyCode)))"
                         : "-\(abs(data.net).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.caption1.bold())
                        .foregroundStyle(data.net >= 0 ? VColors.income : VColors.expense)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private var cashFlowReportErrorBinding: Binding<String?> {
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
        CashFlowReportView()
    }
}
