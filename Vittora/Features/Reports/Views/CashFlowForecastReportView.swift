import SwiftUI
import Charts
import VittoraCore

struct CashFlowForecastReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode

    /// The projection's own currency, falling back to the display default when
    /// there are no accounts. Labelling these with the display currency showed
    /// an INR balance as dollars.
    private func projectionCurrency(_ vm: CashFlowForecastViewModel) -> String {
        vm.projectedCurrencyCode ?? currencyCode
    }
    @State private var vm: CashFlowForecastViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if let result = vm.result {
                        estimateDisclaimer
                        summaryCards(result, vm: vm)
                        forecastChart(vm)
                        inputsNote(result, currency: projectionCurrency(vm))
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Cash Flow Forecast"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = CashFlowForecastViewModel(
                useCase: CashFlowForecastUseCase(
                    accountRepository: dependencies.accountRepository,
                    transactionRepository: dependencies.transactionRepository,
                    recurringRuleRepository: dependencies.recurringRuleRepository,
                    categoryRepository: dependencies.categoryRepository
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
        .task(id: appState.refreshVersion(for: .accounts)) {
            guard vm != nil, appState.refreshVersion(for: .accounts) > 0 else { return }
            await vm?.load()
        }
        .refreshable {
            await vm?.load()
        }
        .errorAlert(message: forecastErrorBinding)
    }

    // MARK: - Disclaimer (required on-screen — DEC-011 / Terms)

    private var estimateDisclaimer: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Label(
                    String(localized: "Estimate — not a guarantee"),
                    systemImage: "info.circle"
                )
                .font(VTypography.calloutBold)
                .foregroundStyle(VColors.textPrimary)

                Text(
                    String(
                        localized: "Projection based on your recurring items and recent spending — not a guarantee."
                    )
                )
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityIdentifier("cash-flow-forecast-disclaimer")
            }
        }
    }

    // MARK: - Summary

    private func summaryCards(_ result: CashFlowForecastResult, vm: CashFlowForecastViewModel) -> some View {
        VCard {
            VStack(spacing: VSpacing.lg) {
                HStack {
                    summaryColumn(
                        title: String(localized: "Today"),
                        amount: result.startingBalance,
                        color: VColors.textPrimary,
                        currency: projectionCurrency(vm)
                    )
                    Spacer()
                    if let day30 = vm.day30Balance {
                        summaryColumn(
                            title: String(localized: "Day 30"),
                            amount: day30,
                            color: day30 >= result.startingBalance ? VColors.income : VColors.expense,
                            currency: projectionCurrency(vm)
                        )
                        .accessibilityIdentifier("cash-flow-forecast-day-30")
                    }
                    Spacer()
                    if let day90 = vm.day90Balance {
                        summaryColumn(
                            title: String(localized: "Day 90"),
                            amount: day90,
                            color: day90 >= result.startingBalance ? VColors.income : VColors.expense,
                            currency: projectionCurrency(vm)
                        )
                    }
                }
            }
        }
    }

    private func summaryColumn(
        title: String,
        amount: Decimal,
        color: Color,
        currency: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Text(CurrencyFormatter.format(amount, currencyCode: currency))
                .font(VTypography.amountSmall)
                .amountScaling()
                .foregroundStyle(color)
        }
    }

    // MARK: - Chart

    private func forecastChart(_ vm: CashFlowForecastViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Projected Balance"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            TrendAreaChart(
                dataPoints: vm.chartPoints,
                color: VColors.primary,
                currencyCode: projectionCurrency(vm)
            )
            .frame(height: 220)
            .padding(VSpacing.md)
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            .accessibilityIdentifier("cash-flow-forecast-chart")
        }
    }

    private func inputsNote(_ result: CashFlowForecastResult, currency: String) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "How this is calculated"))
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                Text(
                    String(
                        localized: "Average daily discretionary spend: \(CurrencyFormatter.format(result.averageDailyDiscretionarySpend, currencyCode: currency)) (from \(result.historyDayCount) days of history)."
                    )
                )
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)

                Text(
                    String(
                        localized: "Scheduled recurring income and expenses are applied on their actual dates; discretionary spend is applied every day."
                    )
                )
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            }
        }
    }

    private var forecastErrorBinding: Binding<String?> {
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
        CashFlowForecastReportView()
    }
}
