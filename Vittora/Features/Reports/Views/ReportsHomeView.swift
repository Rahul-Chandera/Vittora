import SwiftUI

struct ReportsHomeView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: ReportsHomeViewModel?

    private let reportCards: [(type: ReportType, title: String, subtitle: String, icon: String, color: Color)] = [
        (.monthly, String(localized: "Monthly Overview"), String(localized: "Income vs expenses over 12 months"), "chart.bar.fill", .blue),
        (.category, String(localized: "Category Breakdown"), String(localized: "Spending by category with percentages"), "chart.pie.fill", .orange),
        (.trends, String(localized: "Spending Trends"), String(localized: "Daily, weekly, or monthly trend chart"), "chart.line.uptrend.xyaxis", .purple),
        (.custom, String(localized: "Custom Report"), String(localized: "Filter by date, group by category or account"), "slider.horizontal.3", .teal),
        (.annual, String(localized: "Annual Summary"), String(localized: "Review yearly income, spending, and monthly totals"), "calendar", .indigo),
        (.cashFlow, String(localized: "Cash Flow"), String(localized: "Track inflows and outflows over time"), "waveform.path.ecg", .green),
        (.netWorth, String(localized: "Net Worth"), String(localized: "See how your total balance changes over time"), "chart.line.uptrend.xyaxis.circle.fill", .pink)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.sectionSpacing) {
                    if let vm = vm {
                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.cardPadding)
                                .background(VColors.secondaryBackground)
                                .cornerRadius(VSpacing.cornerRadiusCard)
                        } else if vm.error == nil {
                            summaryCard(vm)
                        }
                    }

                    VStack(spacing: VSpacing.md) {
                        ForEach(reportCards, id: \.type) { card in
                            NavigationLink(value: card.type) {
                                ReportCardView(
                                    title: card.title,
                                    subtitle: card.subtitle,
                                    icon: card.icon,
                                    color: card.color
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(VSpacing.screenPadding)
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Reports"))
            .navigationDestination(for: ReportType.self) { type in
                reportView(for: type)
            }
        }
        .task {
            if vm == nil {
                guard let transactionRepo = dependencies.transactionRepository else { return }
                vm = ReportsHomeViewModel(transactionRepository: transactionRepo)
                await vm?.load()
            }
        }
        .errorAlert(message: reportsHomeErrorBinding)
    }

    @ViewBuilder
    private func summaryCard(_ vm: ReportsHomeViewModel) -> some View {
        HStack(spacing: VSpacing.xl) {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(String(localized: "This Month"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
                Text(vm.formattedAmount(vm.monthSpending))
                    .font(VTypography.amountMedium)
                    .foregroundColor(VColors.expense)
                Text(String(localized: "Spent"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xs) {
                Text(String(localized: "This Month"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
                Text(vm.formattedAmount(vm.monthIncome))
                    .font(VTypography.amountMedium)
                    .foregroundColor(VColors.income)
                Text(String(localized: "Earned"))
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    @ViewBuilder
    private func reportView(for type: ReportType) -> some View {
        switch type {
        case .monthly:
            MonthlyOverviewView()
        case .category:
            CategoryBreakdownView()
        case .trends:
            SpendingTrendsView()
        case .custom:
            CustomReportView()
        case .annual:
            AnnualReportView()
        case .cashFlow:
            CashFlowReportView()
        case .netWorth:
            NetWorthReportView()
        }
    }

    private var reportsHomeErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    ReportsHomeView()
}
