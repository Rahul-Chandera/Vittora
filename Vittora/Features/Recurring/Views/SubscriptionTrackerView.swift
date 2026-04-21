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
                                            SubscriptionCard(
                                                rule: rule,
                                                monthlyCost: viewModel.monthlyCost(for: rule)
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
}

#Preview {
    NavigationStack {
        SubscriptionTrackerView()
    }
}
