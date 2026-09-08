import SwiftUI
import Charts
import VittoraCore

struct CashFlowReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: CashFlowReportViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if hasReportData(vm) {
                        projectionNote(vm)
                        cashFlowSummary(vm)
                        cashFlowChart(vm)
                        cashFlowList(vm)
                    } else {
                        emptyState
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Cash Flow"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = CashFlowReportViewModel(
                useCase: CashFlowProjectionUseCase(
                    transactionRepository: dependencies.transactionRepository,
                    recurringRuleRepository: dependencies.recurringRuleRepository
                )
            )
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .transactions)) {
            guard vm != nil, appState.refreshVersion(for: .transactions) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .recurring)) {
            guard vm != nil, appState.refreshVersion(for: .recurring) > 0 else { return }
            await vm?.load()
        }
        .errorAlert(message: cashFlowReportErrorBinding)
    }

    // MARK: - Projection Note

    private func projectionNote(_ vm: CashFlowReportViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Label(String(localized: "Includes 6-month forecast"), systemImage: "chart.line.uptrend.xyaxis")
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                Text(
                    String(
                        localized: "Future months combine scheduled recurring expenses with your average discretionary spending and income from the last 12 months."
                    )
                )
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)

                if !vm.projectedMonths.isEmpty {
                    Text(
                        String(
                            localized: "Projected net (next \(vm.projectedMonths.count) months): \(vm.projectedNetTotal.formatted(.currency(code: currencyCode)))"
                        )
                    )
                    .font(VTypography.caption1.bold())
                    .foregroundStyle(vm.projectedNetTotal >= 0 ? VColors.income : VColors.expense)
                }
            }
        }
    }

    // MARK: - Summary Card

    private func cashFlowSummary(_ vm: CashFlowReportViewModel) -> some View {
        let surplusMonths = vm.actualMonths.filter { $0.net >= 0 }.count
        let deficitMonths = vm.actualMonths.filter { $0.net < 0 }.count
        let avgNet = vm.actualMonths.isEmpty ? Decimal(0)
            : vm.actualMonths.reduce(Decimal(0)) { $0 + $1.net } / Decimal(vm.actualMonths.count)

        return VCard {
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Avg/Month (actual)"))
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

    private func cashFlowChart(_ vm: CashFlowReportViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Monthly Net Cash Flow"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(VColors.textTertiary)

                    ForEach(vm.months) { data in
                        BarMark(
                            x: .value("Month", data.month, unit: .month),
                            y: .value(String(localized: "Net"), data.net)
                        )
                        .foregroundStyle(barColor(for: data))
                        .cornerRadius(4)
                        .opacity(data.isProjected ? 0.55 : 1)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .accessibilityChartDescriptor(
                    CashFlowProjectionChartDescriptor(
                        data: vm.months,
                        currencyCode: currencyCode
                    )
                )
                .frame(height: 220)

                HStack(spacing: VSpacing.lg) {
                    Label(String(localized: "Actual surplus"), systemImage: "square.fill")
                        .foregroundStyle(VColors.income)
                        .font(VTypography.caption1)
                    Label(String(localized: "Actual deficit"), systemImage: "square.fill")
                        .foregroundStyle(VColors.expense)
                        .font(VTypography.caption1)
                    Label(String(localized: "Projected"), systemImage: "square.fill")
                        .foregroundStyle(VColors.textSecondary.opacity(0.55))
                        .font(VTypography.caption1)
                }
            }
        }
    }

    // MARK: - Monthly Net List

    private func cashFlowList(_ vm: CashFlowReportViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Month-by-Month"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(vm.months.reversed()) { data in
                HStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.month.formatted(.dateTime.month(.wide).year()))
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                        if data.isProjected {
                            Text(String(localized: "Projected"))
                                .font(VTypography.caption2)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }
                    .frame(width: 120, alignment: .leading)

                    Spacer()

                    let maxNet = vm.months.map { abs($0.net) }.max() ?? 1
                    let fraction = maxNet > 0 ? Double(truncating: (abs(data.net) / maxNet) as NSDecimalNumber) : 0
                    GeometryReader { geo in
                        let barWidth = geo.size.width * CGFloat(fraction)
                        ZStack(alignment: data.net >= 0 ? .leading : .trailing) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(VColors.secondaryBackground)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: data))
                                .frame(width: max(barWidth, 4), height: 8)
                                .opacity(data.isProjected ? 0.55 : 1)
                        }
                    }
                    .frame(height: 8)

                    Text(data.net >= 0
                         ? "+\(data.net.formatted(.currency(code: currencyCode)))"
                         : "-\(abs(data.net).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.caption1.bold())
                        .foregroundStyle(barColor(for: data))
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func barColor(for data: CashFlowMonth) -> Color {
        if data.isProjected {
            return data.net >= 0 ? VColors.income.opacity(0.65) : VColors.expense.opacity(0.65)
        }
        return data.net >= 0 ? VColors.income : VColors.expense
    }

    private func hasReportData(_ vm: CashFlowReportViewModel) -> Bool {
        vm.actualMonths.contains { $0.displayIncome != 0 || $0.displayExpense != 0 }
            || !vm.projectedMonths.isEmpty
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No cash flow yet"), systemImage: "waveform.path.ecg")
        } description: {
            Text(String(localized: "Income and expense transactions will create your cash-flow view."))
        }
        .padding(VSpacing.xxxl)
        // Centre in the viewport, not pushed down from the top. This sits in a
        // ScrollView, so maxHeight: .infinity alone does nothing — the content
        // has to fill the scroll container's height first for the empty state
        // to have anything to centre within.
        .containerRelativeFrame(.vertical, alignment: .center)
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
