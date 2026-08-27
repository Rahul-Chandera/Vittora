import SwiftUI
import VittoraCore

struct ReportsHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: ReportsHomeViewModel?
    @State private var pendingReportType: ReportType?
    @State private var pendingReportStart: Date?
    @State private var pendingReportEnd: Date?

    // Computed, not stored: the accent-derived colours below read the current
    // theme, and a `let` captured them once at init so switching accent left
    // these icons on the old one until the view was recreated.
    private var reportCards: [(type: ReportType, title: String, subtitle: String, icon: String, color: Color)] {
        [
            (.yearInReview, String(localized: "Year in Review"), String(localized: "Your Wrapped — a shareable look at the year"), "sparkles", VColors.primaryOnSurface),
            (.monthly, String(localized: "Monthly Overview"), String(localized: "Income vs expenses over 12 months"), "chart.bar.fill", VColors.primaryOnSurface),
            (.category, String(localized: "Category Breakdown"), String(localized: "Spending by category with percentages"), "chart.pie.fill", VColors.warning),
            (.trends, String(localized: "Spending Trends"), String(localized: "Daily, weekly, or monthly trend chart"), "chart.line.uptrend.xyaxis", VColors.savings),
            (.custom, String(localized: "Custom Report"), String(localized: "Filter by date, group by category or account"), "slider.horizontal.3", VColors.transfer),
            (.annual, String(localized: "Annual Summary"), String(localized: "Review yearly income, spending, and monthly totals"), "calendar", VColors.primaryOnSurface),
            (.cashFlow, String(localized: "Cash Flow"), String(localized: "Track inflows and outflows over time"), "waveform.path.ecg", VColors.income),
            (.cashFlowForecast, String(localized: "Cash Flow Forecast"), String(localized: "90-day projected balance estimate"), "chart.xyaxis.line", VColors.primaryOnSurface),
            (.netWorth, String(localized: "Net Worth"), String(localized: "See how your total balance changes over time"), "chart.line.uptrend.xyaxis.circle.fill", VColors.savings),
            (.subscriptionAudit, String(localized: "Subscription Audit"), String(localized: "What recurring expenses cost each month"), "arrow.triangle.2.circlepath", VColors.transfer),
            (.fiftyThirtyTwenty, String(localized: "50/30/20"), String(localized: "Compare needs, wants, and savings with the guideline"), "chart.bar.xaxis", VColors.savings),
            (.emergencyFund, String(localized: "Emergency Fund"), String(localized: "See how many months of essentials you could cover"), "shield.lefthalf.filled", VColors.savings)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.sectionSpacing) {
                    if let vm = vm {
                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.cardPadding)
                                .background(VColors.secondaryGroupedBackground)
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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(card.title)
                            .accessibilityHint(card.subtitle)
                            .accessibilityIdentifier("report-card-\(card.type.rawValue)")
                        }
                    }
                }
                .padding(VSpacing.screenPadding)
            }
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Reports"))
            .navigationDestination(for: ReportType.self) { type in
                reportView(for: type)
                    .advertisesHandoff(.reportDetail(type: type.rawValue, start: nil, end: nil))
            }
            .navigationDestination(item: $pendingReportType) { type in
                reportView(for: type)
                    .advertisesHandoff(
                        .reportDetail(
                            type: type.rawValue,
                            start: pendingReportStart,
                            end: pendingReportEnd
                        )
                    )
            }
        }
        .task {
            dependencies.conversionEventRecorder.afterReportOpened()
        }
        // Keyed on the transaction version, like DashboardView: the summary card
        // aggregates transactions, so a once-only load left it showing the totals
        // from whenever the tab first appeared. Adding a transaction and coming
        // back showed stale figures — and on a fresh launch it showed zeroes.
        .task(id: appState.transactionsRefreshVersion) {
            if vm == nil {
                vm = ReportsHomeViewModel(transactionRepository: dependencies.transactionRepository)
            }
            await vm?.load()
        }
        .task(id: appState.pendingReportHandoff?.typeRaw) {
            guard let pending = appState.pendingReportHandoff,
                  let type = pending.reportType
            else {
                return
            }
            pendingReportStart = pending.start
            pendingReportEnd = pending.end
            pendingReportType = type
            appState.clearPendingReportHandoff()
        }
        .errorAlert(message: reportsHomeErrorBinding)
    }

    @ViewBuilder
    private func summaryCard(_ vm: ReportsHomeViewModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VSpacing.xl) {
                spentSummary(vm)
                Spacer(minLength: 0)
                earnedSummary(vm)
            }
            VStack(alignment: .leading, spacing: VSpacing.md) {
                spentSummary(vm)
                earnedSummary(vm)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "This month summary"))
        .accessibilityValue(
            String(
                localized: "Spent \(CurrencyFormatter.format(vm.monthSpending, currencyCode: currencyCode)), earned \(CurrencyFormatter.format(vm.monthIncome, currencyCode: currencyCode))"
            )
        )
    }

    private func spentSummary(_ vm: ReportsHomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(String(localized: "This Month"))
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
            Text(CurrencyFormatter.format(vm.monthSpending, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundColor(VColors.expense)
            Text(String(localized: "Spent"))
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
    }

    private func earnedSummary(_ vm: ReportsHomeViewModel) -> some View {
        VStack(alignment: .trailing, spacing: VSpacing.xs) {
            Text(String(localized: "This Month"))
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
            Text(CurrencyFormatter.format(vm.monthIncome, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundColor(VColors.income)
            Text(String(localized: "Earned"))
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
    }

    @ViewBuilder
    private func reportView(for type: ReportType) -> some View {
        switch type {
        case .fiftyThirtyTwenty:
            FiftyThirtyTwentyReportView()
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
        case .cashFlowForecast:
            CashFlowForecastReportView()
        case .netWorth:
            NetWorthReportView()
        case .subscriptionAudit:
            SubscriptionAuditReportView()
        case .emergencyFund:
            EmergencyFundReportView()
        case .yearInReview:
            YearInReviewView()
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
