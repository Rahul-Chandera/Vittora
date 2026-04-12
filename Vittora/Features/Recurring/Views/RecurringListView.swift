import SwiftUI

struct RecurringListView: View {
    @Environment(\.dependencies) var dependencies
    @State private var viewModel: RecurringListViewModel?
    @State private var showAddSheet = false
    @State private var selectedRuleID: UUID? = nil

    var body: some View {
        ZStack {
            VColors.background.ignoresSafeArea()

            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    // Cost Summary Card
                    if let costSummary = viewModel.costSummary {
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            Text("Monthly Spend")
                                .font(VTypography.callout)
                                .foregroundColor(VColors.textSecondary)

                            HStack(spacing: VSpacing.xl) {
                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                    Text(String(format: "$%.2f", Double(truncating: costSummary.monthlyCost as NSDecimalNumber)))
                                        .font(VTypography.amountLarge)
                                        .foregroundColor(VColors.expense)

                                    Text("per month")
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: VSpacing.xs) {
                                    Text(String(format: "$%.2f", Double(truncating: costSummary.annualCost as NSDecimalNumber)))
                                        .font(VTypography.bodyBold)
                                        .foregroundColor(VColors.expense)

                                    Text("per year")
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textSecondary)
                                }
                            }

                            Divider()
                                .padding(.vertical, VSpacing.md)

                            HStack {
                                Image(systemName: "repeat")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(VColors.primary)

                                Text("\(costSummary.ruleCount) active \(costSummary.ruleCount == 1 ? "subscription" : "subscriptions")")
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)

                                Spacer()
                            }
                        }
                        .padding(VSpacing.lg)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusMD)
                        .padding(VSpacing.lg)
                    }

                    if viewModel.rules.isEmpty {
                        VStack(spacing: VSpacing.lg) {
                            Image(systemName: "repeat.circle")
                                .font(.system(size: 48))
                                .foregroundColor(VColors.textSecondary)

                            Text("No Recurring Transactions")
                                .font(VTypography.title3)
                                .foregroundColor(VColors.textPrimary)

                            Text("Create your first recurring transaction to get started")
                                .font(VTypography.callout)
                                .foregroundColor(VColors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: { showAddSheet = true }) {
                                Text("Add Recurring Transaction")
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(VSpacing.md)
                                    .background(VColors.primary)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                            }
                            .padding(.top, VSpacing.lg)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(VSpacing.lg)
                    } else {
                        List {
                            ForEach(viewModel.grouped, id: \.label) { group in
                                Section(header: Text(group.label).font(VTypography.calloutBold)) {
                                    ForEach(group.rules, id: \.id) { rule in
                                        NavigationLink(destination: RecurringDetailView(ruleID: rule.id)) {
                                            RecurringRowView(rule: rule)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                Task {
                                                    await viewModel.togglePause(id: rule.id)
                                                }
                                            } label: {
                                                Label(
                                                    rule.isActive ? "Pause" : "Resume",
                                                    systemImage: rule.isActive ? "pause.circle.fill" : "play.circle.fill"
                                                )
                                            }
                                            .tint(.orange)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.deleteRule(id: rule.id)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        #if os(iOS)
                        .listStyle(.insetGrouped)
                        #else
                        .listStyle(.inset)
                        #endif
                    }
                }

                if let error = viewModel.error {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)

                            Text(error)
                                .font(VTypography.callout)
                                .foregroundColor(.red)

                            Spacer()
                        }
                        .padding(VSpacing.md)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(VSpacing.cornerRadiusMD)
                        .padding(VSpacing.lg)

                        Spacer()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Recurring Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RecurringFormView(onDismiss: {
                showAddSheet = false
                Task {
                    await viewModel?.loadRules()
                }
            })
        }
        .onAppear {
            if viewModel == nil {
                setupViewModel()
            }
            Task {
                await viewModel?.loadRules()
            }
        }
    }

    private func setupViewModel() {
        guard let recurringRepo = dependencies.recurringRuleRepository else { return }

        let fetchUseCase = FetchRecurringRulesUseCase(repository: recurringRepo)
        let deleteUseCase = DeleteRecurringRuleUseCase(repository: recurringRepo)
        let pauseResumeUseCase = PauseResumeRuleUseCase(repository: recurringRepo)
        let calculateCostUseCase = CalculateSubscriptionCostUseCase()

        viewModel = RecurringListViewModel(
            fetchUseCase: fetchUseCase,
            deleteUseCase: deleteUseCase,
            pauseResumeUseCase: pauseResumeUseCase,
            calculateCostUseCase: calculateCostUseCase
        )
    }
}

#Preview {
    NavigationStack {
        RecurringListView()
    }
}
