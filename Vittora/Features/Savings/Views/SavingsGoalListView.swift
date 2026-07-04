import SwiftUI

struct SavingsGoalListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: SavingsGoalListViewModel?
    @State private var showAddGoal = false
    @State private var selectedGoalID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                if let vm {
                    if vm.isLoading && vm.goals.isEmpty {
                        ProgressView().tint(VColors.primary)
                    } else if vm.goals.isEmpty {
                        emptyState
                    } else {
                        listContent(vm)
                    }
                }
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Savings Goals"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedGoalID) { id in
                if let goal = vm?.goals.first(where: { $0.id == id }) {
                    SavingsGoalDetailView(initialGoal: goal, currencyCode: currencyCode)
                }
            }
        }
        .task {
            if vm == nil {
                guard let repo = dependencies.savingsGoalRepository else { return }
                vm = SavingsGoalListViewModel(
                    fetchUseCase: FetchSavingsGoalsUseCase(savingsGoalRepository: repo),
                    saveUseCase: SaveSavingsGoalUseCase(savingsGoalRepository: repo)
                )
                await vm?.load()
            }
        }
        .task(id: appState.dataRefreshVersion) {
            guard vm != nil, appState.dataRefreshVersion > 0 else { return }
            await vm?.load()
        }
        .sheet(isPresented: $showAddGoal) {
            SavingsGoalFormView {
                Task { await vm?.load() }
            }
        }
        .refreshable {
            await vm?.load()
        }
        .alert(String(localized: "Error"), isPresented: Binding(
            get: { vm?.error != nil },
            set: { if !$0 { vm?.error = nil } }
        )) {
            Button(String(localized: "OK")) { vm?.error = nil }
        } message: {
            Text(vm?.error ?? "")
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private func listContent(_ vm: SavingsGoalListViewModel) -> some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                // Summary header
                if let summary = vm.summary, summary.totalGoals > 0 {
                    summaryHeader(summary)
                }

                // Overdue banner
                if !vm.overdueGoals.isEmpty {
                    HStack(spacing: VSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                        Text(String(localized: "\(vm.overdueGoals.count) goal(s) past deadline"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(VSpacing.md)
                    .background(VColors.expense)
                    .cornerRadius(VSpacing.cornerRadiusMD)
                }

                // Active goals
                if !vm.activeGoals.isEmpty {
                    goalSection(title: String(localized: "Active"), goals: vm.activeGoals, vm: vm)
                }

                // Achieved goals
                if !vm.achievedGoals.isEmpty {
                    goalSection(title: String(localized: "Achieved 🎉"), goals: vm.achievedGoals, vm: vm)
                }
            }
            .padding(VSpacing.screenPadding)
        }
    }

    private func summaryHeader(_ summary: GoalProgressSummary) -> some View {
        VCard {
            HStack(spacing: VSpacing.lg) {
                SavingsProgressRingView(
                    progress: summary.overallProgressFraction,
                    color: VColors.primary,
                    size: 56,
                    lineWidth: 6
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Overall Progress"))
                        .font(VTypography.subheadline)
                        .foregroundStyle(VColors.textSecondary)
                    HStack(spacing: 4) {
                        Text(summary.totalSavedAmount.formatted(.currency(code: currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.income)
                        Text(String(localized: "of"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(summary.totalTargetAmount.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                    Text(String(localized: "\(summary.activeGoals) active · \(summary.achievedGoals) achieved"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func goalSection(title: String, goals: [SavingsGoalEntity], vm: SavingsGoalListViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(title)
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            ForEach(goals) { goal in
                Button { selectedGoalID = goal.id } label: {
                    SavingsGoalCardView(goal: goal, currencyCode: currencyCode)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await vm.delete(id: goal.id)
                            appState.notifyDataChanged()
                        }
                    } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
            Text(String(localized: "No savings goals"))
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Create a goal and track your progress toward financial milestones"))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Create Goal")) { showAddGoal = true }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }
}

#Preview {
    SavingsGoalListView()
}
