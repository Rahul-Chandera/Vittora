import SwiftUI

struct SubscriptionTrackerView: View {
    @Environment(\.dependencies) var dependencies
    @State private var viewModel: SubscriptionSummaryViewModel?

    var body: some View {
        ZStack {
            VColors.background.ignoresSafeArea()

            if let viewModel = viewModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: VSpacing.lg) {
                        // Summary Card
                        if let costSummary = viewModel.costSummary {
                            VStack(alignment: .leading, spacing: VSpacing.lg) {
                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                    Text(String(localized: "Monthly Spending"))
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)

                                    Text(String(format: "$%.2f", Double(truncating: costSummary.monthlyCost as NSDecimalNumber)))
                                        .font(VTypography.largeTitle)
                                        .foregroundColor(VColors.expense)
                                }

                                Divider()

                                HStack(spacing: VSpacing.xl) {
                                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                                        Text(String(localized: "Yearly Estimate"))
                                            .font(VTypography.caption2)
                                            .foregroundColor(VColors.textSecondary)

                                        Text(String(format: "$%.2f", Double(truncating: costSummary.annualCost as NSDecimalNumber)))
                                            .font(VTypography.title3)
                                            .foregroundColor(VColors.expense)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                                        Text(String(localized: "Active Subscriptions"))
                                            .font(VTypography.caption2)
                                            .foregroundColor(VColors.textSecondary)

                                        Text("\(costSummary.ruleCount)")
                                            .font(VTypography.title3)
                                            .foregroundColor(VColors.primary)
                                    }
                                }
                            }
                            .padding(VSpacing.lg)
                            .background(VColors.secondaryBackground)
                            .cornerRadius(VSpacing.cornerRadiusMD)

                            // Breakdown
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text(String(localized: "Your Subscriptions"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                if viewModel.activeRules.isEmpty {
                                    VStack(spacing: VSpacing.md) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 48))
                                            .foregroundColor(.green)

                                        Text(String(localized: "No Active Subscriptions"))
                                            .font(VTypography.title3)
                                            .foregroundColor(VColors.textPrimary)

                                        Text(String(localized: "You're all set! No recurring expenses scheduled."))
                                            .font(VTypography.callout)
                                            .foregroundColor(VColors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(VSpacing.xl)
                                } else {
                                    VStack(spacing: VSpacing.md) {
                                        ForEach(viewModel.activeRules, id: \.id) { rule in
                                            let monthlyCost = normalizeToMonthlyCost(
                                                amount: rule.templateAmount,
                                                frequency: rule.frequency
                                            )
                                            SubscriptionCard(
                                                rule: rule,
                                                monthlyCost: monthlyCost
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Spacer()
                            .frame(height: VSpacing.xl)
                    }
                    .padding(VSpacing.lg)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Subscriptions"))
        .onAppear {
            if viewModel == nil {
                setupViewModel()
            }
            Task {
                await viewModel?.load()
            }
        }
    }

    private func setupViewModel() {
        guard let repo = dependencies.recurringRuleRepository else { return }
        let fetchUseCase = FetchRecurringRulesUseCase(
            repository: repo
        )
        let calculateCostUseCase = CalculateSubscriptionCostUseCase()

        viewModel = SubscriptionSummaryViewModel(
            fetchUseCase: fetchUseCase,
            calculateCostUseCase: calculateCostUseCase
        )
    }

    private func normalizeToMonthlyCost(amount: Decimal, frequency: RecurrenceFrequency) -> Decimal {
        switch frequency {
        case .daily:
            return amount * 30
        case .weekly:
            return amount * (Decimal(string: "4.33") ?? 4.33)
        case .biweekly:
            return amount * (Decimal(string: "2.165") ?? 2.165)
        case .monthly:
            return amount * 1
        case .quarterly:
            return amount / 3
        case .yearly:
            return amount / 12
        case .custom(let days):
            let daysPerMonth = Decimal(string: "30.0") ?? 30.0
            let daysFraction = Decimal(days) > 0 ? daysPerMonth / Decimal(days) : 1
            return amount * daysFraction
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionTrackerView()
    }
}
