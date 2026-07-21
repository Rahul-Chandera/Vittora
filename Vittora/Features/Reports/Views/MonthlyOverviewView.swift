import SwiftUI
import Charts
import VittoraCore

struct MonthlyOverviewView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: MonthlyOverviewViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm = vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else if hasReportData(vm) {
                        summaryRow(vm)
                        chartSection(vm)
                        monthTable(vm)
                    } else {
                        emptyState
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Monthly Overview"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let vm, hasReportData(vm) {
                    ReportPDFShareLink(
                        fileName: "monthly-overview",
                        contentVersion: monthlyReportContentVersion(vm),
                        isEnabled: !vm.isLoading
                    ) {
                        try ReportPDFRenderer.export(
                            pages: MonthlyReportPDFDocument.pages(
                                reportTitle: String(localized: "Monthly Overview"),
                                period: String(localized: "Last 12 months"),
                                monthlyData: vm.monthlyData,
                                currencyCode: currencyCode,
                                totalIncome: vm.totalIncome,
                                totalExpense: vm.totalExpense,
                                netSavings: vm.netSavings
                            ),
                            fileName: "monthly-overview"
                        )
                    }
                }
            }
        }
        .task {
            if vm == nil {
                let useCase = MonthlyOverviewUseCase(transactionRepository: dependencies.transactionRepository)
                vm = MonthlyOverviewViewModel(useCase: useCase)
                await vm?.load()
            }
        }
        .errorAlert(message: monthlyOverviewErrorBinding)
    }

    @ViewBuilder
    private func summaryRow(_ vm: MonthlyOverviewViewModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VSpacing.md) {
                statCard(title: String(localized: "Total Income"), amount: vm.totalIncome, color: VColors.income)
                statCard(title: String(localized: "Total Expense"), amount: vm.totalExpense, color: VColors.expense)
                statCard(title: String(localized: "Net Savings"), amount: vm.netSavings, color: vm.netSavings >= 0 ? VColors.income : VColors.expense)
            }
            VStack(spacing: VSpacing.md) {
                statCard(title: String(localized: "Total Income"), amount: vm.totalIncome, color: VColors.income)
                statCard(title: String(localized: "Total Expense"), amount: vm.totalExpense, color: VColors.expense)
                statCard(title: String(localized: "Net Savings"), amount: vm.netSavings, color: vm.netSavings >= 0 ? VColors.income : VColors.expense)
            }
        }
    }

    private func statCard(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
            Text(CurrencyFormatter.formatCompact(amount, currencyCode: currencyCode))
                .font(VTypography.amountSmall)
                .amountScaling()
                .foregroundColor(color)
        }
        .padding(VSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(CurrencyFormatter.format(amount, currencyCode: currencyCode))
    }

    @ViewBuilder
    private func chartSection(_ vm: MonthlyOverviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Last 12 Months"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            IncomeExpenseBarChart(data: vm.monthlyData, currencyCode: currencyCode)
                .frame(height: 220)
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    @ViewBuilder
    private func monthTable(_ vm: MonthlyOverviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Monthly Breakdown"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            VStack(spacing: 0) {
                ForEach(vm.monthlyData.reversed()) { item in
                    HStack {
                        Text(item.month.formatted(.dateTime.year().month(.wide)))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textPrimary)

                        Spacer()

                        Text(CurrencyFormatter.formatCompact(item.income, currencyCode: currencyCode))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.income)
                            .frame(width: 80, alignment: .trailing)

                        Text(CurrencyFormatter.formatCompact(item.expense, currencyCode: currencyCode))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.expense)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, VSpacing.sm)
                    .padding(.horizontal, VSpacing.md)

                    Divider()
                        .padding(.leading, VSpacing.md)
                }
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private func hasReportData(_ vm: MonthlyOverviewViewModel) -> Bool {
        vm.monthlyData.contains { $0.income != 0 || $0.expense != 0 }
    }

    private func monthlyReportContentVersion(_ vm: MonthlyOverviewViewModel) -> String {
        let monthKeys = vm.monthlyData
            .map { String($0.month.timeIntervalSince1970) }
            .joined(separator: ",")
        return "monthly|\(vm.totalIncome)|\(vm.totalExpense)|\(vm.netSavings)|\(monthKeys)"
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No monthly data yet"), systemImage: "chart.bar")
        } description: {
            Text(String(localized: "Transactions from the last 12 months will appear here once you add them."))
        }
        .padding(VSpacing.xxxl)
    }

    private var monthlyOverviewErrorBinding: Binding<String?> {
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
        MonthlyOverviewView()
    }
}
