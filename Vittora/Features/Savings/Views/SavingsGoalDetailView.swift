import SwiftUI

struct SavingsGoalDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SavingsGoalDetailViewModel?
    @State private var showEditForm = false

    let initialGoal: SavingsGoalEntity
    let currencyCode: String

    private var goalColor: Color { Color(hex: vm?.goal.colorHex ?? initialGoal.colorHex) ?? VColors.primary }

    private var currencySymbol: String {
        String.currencySymbol(for: currencyCode)
    }

    var body: some View {
        ZStack {
            if let vm {
                detailContent(vm)
            } else {
                ProgressView().tint(VColors.primary)
            }
        }
        .background(VColors.background)
        .navigationTitle(vm?.goal.name ?? initialGoal.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) { showEditForm = true }
            }
            if let vm, vm.goal.status == .active {
                ToolbarItem(placement: .secondaryAction) {
                    Button(vm.goal.status == .paused
                           ? String(localized: "Resume")
                           : String(localized: "Pause")) {
                        Task { await vm.togglePause() }
                    }
                }
            }
        }
        .task {
            guard vm == nil, let repo = dependencies.savingsGoalRepository else { return }
            vm = SavingsGoalDetailViewModel(
                goal: initialGoal,
                saveUseCase: SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            )
        }
        .sheet(isPresented: $showEditForm) {
            if let vm {
                SavingsGoalFormView(existingGoal: vm.goal) {
                    Task {
                        guard let repo = dependencies.savingsGoalRepository else { return }
                        do {
                            guard let fresh = try await repo.fetchByID(vm.goal.id) else { return }
                            vm.goal = fresh
                        } catch {
                            vm.error = error.localizedDescription
                        }
                    }
                }
            }
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

    @ViewBuilder
    private func detailContent(_ vm: SavingsGoalDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                // Hero ring + amounts
                heroSection(vm)

                // Deadline countdown
                if let days = vm.goal.daysRemaining {
                    deadlineCard(days: days, goal: vm.goal)
                }

                // Monthly savings needed
                if let monthly = vm.goal.monthlySavingsNeeded {
                    monthlySavingsCard(monthly: monthly)
                }

                // Contribution input (active goals only)
                if vm.goal.status == .active {
                    contributionSection(vm)
                }

                // Note
                if let note = vm.goal.note, !note.isEmpty {
                    VCard {
                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                            Label(String(localized: "Note"), systemImage: "note.text")
                                .font(VTypography.subheadline)
                                .foregroundStyle(VColors.textSecondary)
                            Text(note)
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                        }
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
    }

    private func heroSection(_ vm: SavingsGoalDetailViewModel) -> some View {
        VCard {
            VStack(spacing: VSpacing.md) {
                SavingsProgressRingView(
                    progress: vm.goal.progressFraction,
                    color: goalColor,
                    size: 120,
                    lineWidth: 12
                )

                VStack(spacing: 4) {
                    Text(vm.goal.currentAmount.formatted(.currency(code: currencyCode)))
                        .font(VTypography.amountLarge)
                        .foregroundStyle(goalColor)
                    Text(String(localized: "saved of \(vm.goal.targetAmount.formatted(.currency(code: currencyCode)))"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }

                if vm.goal.remainingAmount > 0 {
                    Text(String(localized: "\(vm.goal.remainingAmount.formatted(.currency(code: currencyCode))) remaining"))
                        .font(VTypography.caption1.bold())
                        .foregroundStyle(VColors.expense)
                        .padding(.horizontal, VSpacing.md)
                        .padding(.vertical, 6)
                        .background(VColors.expense.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func deadlineCard(days: Int, goal: SavingsGoalEntity) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: days < 0 ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(days < 0 ? VColors.expense : VColors.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(days < 0
                     ? String(localized: "\(abs(days)) days overdue")
                     : days == 0
                     ? String(localized: "Due today!")
                     : String(localized: "\(days) days remaining"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(days < 0 ? VColors.expense : VColors.textPrimary)

                if let date = goal.targetDate {
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(days < 0 ? VColors.expense.opacity(0.08) : VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func monthlySavingsCard(monthly: Decimal) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(VColors.income)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Save monthly to hit deadline"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                Text(monthly.formatted(.currency(code: currencyCode)) + String(localized: "/month"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.income)
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func contributionSection(_ vm: SavingsGoalDetailViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Add Contribution"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                HStack {
                    Text(currencySymbol)
                        .foregroundStyle(VColors.textSecondary)
                    TextField(String(localized: "Amount"), text: Bindable(vm).contributionString)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Spacer()
                    Button {
                        Task { await vm.addContribution() }
                    } label: {
                        if vm.isAddingContribution {
                            ProgressView().tint(.white)
                        } else {
                            Text(String(localized: "Add"))
                                .font(VTypography.bodyBold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(goalColor)
                    .disabled(!vm.canContribute || vm.isAddingContribution)
                }
            }
        }
    }
}
