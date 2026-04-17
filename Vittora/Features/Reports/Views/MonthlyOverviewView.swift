import SwiftUI
import Charts

struct MonthlyOverviewView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: MonthlyOverviewViewModel?

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? "USD"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm = vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else {
                        summaryRow(vm)
                        chartSection(vm)
                        monthTable(vm)
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
        .task {
            if vm == nil {
                guard let repo = dependencies.transactionRepository else { return }
                let useCase = MonthlyOverviewUseCase(transactionRepository: repo)
                vm = MonthlyOverviewViewModel(useCase: useCase)
                await vm?.load()
            }
        }
        .errorAlert(message: monthlyOverviewErrorBinding)
    }

    @ViewBuilder
    private func summaryRow(_ vm: MonthlyOverviewViewModel) -> some View {
        HStack(spacing: VSpacing.md) {
            statCard(title: String(localized: "Total Income"), amount: vm.totalIncome, color: VColors.income)
            statCard(title: String(localized: "Total Expense"), amount: vm.totalExpense, color: VColors.expense)
            statCard(title: String(localized: "Net Savings"), amount: vm.netSavings, color: vm.netSavings >= 0 ? VColors.income : VColors.expense)
        }
    }

    private func statCard(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
                .lineLimit(1)
            Text(formattedAmount(amount))
                .font(VTypography.amountSmall)
                .foregroundColor(color)
        }
        .padding(VSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
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

                        Text(formattedAmount(item.income))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.income)
                            .frame(width: 80, alignment: .trailing)

                        Text(formattedAmount(item.expense))
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

    private func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
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
