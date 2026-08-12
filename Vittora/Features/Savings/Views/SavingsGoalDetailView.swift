import SwiftUI
import VittoraCore

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
        .background(VColors.groupedBackground)
        .navigationTitle(vm?.goal.name ?? initialGoal.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) { showEditForm = true }
                    .font(.body)
                    .foregroundStyle(VColors.textPrimary)
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
            guard vm == nil else { return }
            vm = SavingsGoalDetailViewModel(
                goal: initialGoal,
                saveUseCase: SaveSavingsGoalUseCase(
                    savingsGoalRepository: dependencies.savingsGoalRepository,
                    transactionRepository: dependencies.transactionRepository
                )
            )
        }
        .sheet(isPresented: $showEditForm) {
            if let vm {
                SavingsGoalFormView(existingGoal: vm.goal) {
                    Task {
                        do {
                            guard let fresh = try await dependencies.savingsGoalRepository.fetchByID(vm.goal.id) else { return }
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

                // Savings plan
                if vm.goal.status == .active, vm.goal.remainingAmount > 0 {
                    allocationPlanCard(vm.goal.allocationSnapshot)
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
                    // The goal's own colour — see SavingsGoalCardView.
                    color: Color(hex: vm.goal.colorHex) ?? VColors.primary,
                    size: 120,
                    lineWidth: 12
                )

                VStack(spacing: 4) {
                    Text(vm.goal.currentAmount.formatted(.currency(code: currencyCode)))
                        .font(VTypography.amountLarge)
                        .amountScaling()
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "saved of \(vm.goal.targetAmount.formatted(.currency(code: currencyCode)))"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                }

                if vm.goal.remainingAmount > 0 {
                    Text(String(localized: "\(vm.goal.remainingAmount.formatted(.currency(code: currencyCode))) remaining"))
                        .font(VTypography.caption1.bold())
                        .foregroundStyle(VColors.textPrimary)
                        .padding(.horizontal, VSpacing.md)
                        .padding(.vertical, 6)
                        .background(VColors.expense.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vm.goal.name)
        .accessibilityValue(
            String(
                localized: "\(vm.goal.currentAmount.formatted(.currency(code: currencyCode))) saved of \(vm.goal.targetAmount.formatted(.currency(code: currencyCode))), \(Int(vm.goal.progressFraction * 100)) percent complete, \(vm.goal.remainingAmount.formatted(.currency(code: currencyCode))) remaining"
            )
        )
    }

    private func deadlineCard(days: Int, goal: SavingsGoalEntity) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: days < 0 ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(days < 0 ? VColors.expense : VColors.primaryOnSurface)
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
                        .foregroundStyle(VColors.textPrimary)
                }
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(days < 0 ? VColors.expense.opacity(0.08) : VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func allocationPlanCard(_ snapshot: SavingsAllocationSnapshot) -> some View {
        HStack(alignment: .top, spacing: VSpacing.md) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(VColors.income)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                if let monthly = snapshot.monthlyRequired {
                    Text(String(localized: "Suggested monthly savings"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                    Text(monthly.formatted(.currency(code: currencyCode)) + String(localized: "/month"))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                }
                if let projected = snapshot.projectedCompletionDate {
                    Text(String(localized: "Projected completion"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                        .padding(.top, snapshot.monthlyRequired == nil ? 0 : VSpacing.xs)
                    Text(projected.formatted(date: .long, time: .omitted))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                }
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func contributionSection(_ vm: SavingsGoalDetailViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Add Contribution"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textPrimary)

                HStack {
                    Text(currencySymbol)
                        .foregroundStyle(VColors.textPrimary)
                        .accessibilityHidden(true)
                    TextField(
                        "",
                        text: Bindable(vm).contributionString,
                        prompt: Text(String(localized: "Amount"))
                            .foregroundStyle(VColors.textPrimary)
                    )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textContentType(nil)
                        #endif
                        .accessibilityLabel(String(localized: "Contribution amount"))
                        .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                        .accessibilityIdentifier("savings-contribution-field")
                    Spacer()
                    Button {
                        guard vm.canContribute, !vm.isAddingContribution else { return }
                        Task { await vm.addContribution() }
                    } label: {
                        if vm.isAddingContribution {
                            ProgressView().tint(VColors.textPrimary)
                        } else {
                            Text(String(localized: "Add"))
                                .font(VTypography.bodyBold)
                        }
                    }
                    .padding(.horizontal, VSpacing.md)
                    .frame(minHeight: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                            .stroke(VColors.textPrimary, lineWidth: 1)
                    }
                    .foregroundStyle(VColors.textPrimary)
                    .buttonStyle(.plain)
                    .accessibilityRespondsToUserInteraction(vm.canContribute && !vm.isAddingContribution)
                    .accessibilityIdentifier("savings-contribution-add-button")
                }
            }
        }
    }
}
