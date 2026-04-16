import SwiftUI
import Charts

struct AnnualReportView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: MonthlyOverviewViewModel?
    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private let availableYears: [Int] = {
        let year = Calendar.current.component(.year, from: .now)
        return [year - 2, year - 1, year]
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                yearPicker

                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else {
                        annualSummaryCard(vm)
                        annualChart(vm)
                        monthBreakdownList(vm)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Annual Report"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadData()
        }
        .onChange(of: selectedYear) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        Picker(String(localized: "Year"), selection: $selectedYear) {
            ForEach(availableYears, id: \.self) { year in
                Text(verbatim: "\(year)").tag(year)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Select year"))
    }

    // MARK: - Annual Summary

    private func annualSummaryCard(_ vm: MonthlyOverviewViewModel) -> some View {
        let net = vm.netSavings
        return VCard {
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Income"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    VAmountText(income: vm.totalIncome, size: .body)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text(String(localized: "Net"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(net >= 0
                         ? net.formatted(.currency(code: currencyCode))
                         : "-\(abs(net).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.bodyBold)
                        .foregroundStyle(net >= 0 ? VColors.income : VColors.expense)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "Expenses"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    VAmountText(expense: vm.totalExpense, size: .body)
                }
            }
        }
    }

    // MARK: - Annual Bar Chart

    private func annualChart(_ vm: MonthlyOverviewViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Income vs Expenses"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                Chart {
                    ForEach(vm.monthlyData) { data in
                        BarMark(
                            x: .value("Month", data.month, unit: .month),
                            y: .value(String(localized: "Income"), data.income),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(VColors.income)
                        .offset(x: -6)

                        BarMark(
                            x: .value("Month", data.month, unit: .month),
                            y: .value(String(localized: "Expense"), data.expense),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(VColors.expense)
                        .offset(x: 6)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
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
                    MonthlyIncomeExpenseChartDescriptor(
                        data: vm.monthlyData,
                        currencyCode: currencyCode
                    )
                )
                .frame(height: 200)

                HStack(spacing: VSpacing.lg) {
                    Label(String(localized: "Income"), systemImage: "square.fill")
                        .foregroundStyle(VColors.income)
                        .font(VTypography.caption1)
                    Label(String(localized: "Expenses"), systemImage: "square.fill")
                        .foregroundStyle(VColors.expense)
                        .font(VTypography.caption1)
                }
            }
        }
    }

    // MARK: - Month-by-Month List

    private func monthBreakdownList(_ vm: MonthlyOverviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Monthly Breakdown"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(vm.monthlyData.reversed()) { data in
                HStack {
                    Text(data.month.formatted(.dateTime.month(.wide)))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textPrimary)
                        .frame(width: 90, alignment: .leading)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(data.income.formatted(.currency(code: currencyCode)))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.income)
                        }
                        HStack(spacing: 4) {
                            Text(data.expense.formatted(.currency(code: currencyCode)))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.expense)
                        }
                    }
                    Spacer()
                    let net = data.net
                    Text(net >= 0
                         ? "+\(net.formatted(.currency(code: currencyCode)))"
                         : "-\(abs(net).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.caption1.bold())
                        .foregroundStyle(net >= 0 ? VColors.income : VColors.expense)
                        .frame(width: 90, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    // MARK: - Helpers

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? "USD"
    }

    private func loadData() async {
        guard let repo = dependencies.transactionRepository else { return }
        if vm == nil {
            let useCase = MonthlyOverviewUseCase(transactionRepository: repo)
            vm = MonthlyOverviewViewModel(useCase: useCase)
        }
        await vm?.load()
    }
}

#Preview {
    NavigationStack {
        AnnualReportView()
    }
}
