import SwiftUI

struct SplitGroupDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SplitGroupDetailViewModel?
    @State private var showAddExpense = false
    @State private var showEditGroup = false

    let group: SplitGroup

    var body: some View {
        ZStack {
            if let vm {
                if vm.isLoading && vm.expenses.isEmpty {
                    ProgressView().tint(VColors.primary)
                } else {
                    detailContent(vm)
                }
            } else {
                ProgressView().tint(VColors.primary)
            }
        }
        .background(VColors.background)
        .navigationTitle(group.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(String(localized: "Edit Group")) {
                    showEditGroup = true
                }
            }
            if let vm, !vm.outstandingExpenses.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    Button(String(localized: "Settle All")) {
                        Task { await vm.settleAll() }
                    }
                }
            }
        }
        .task {
            if vm == nil {
                guard let splitRepo = dependencies.splitGroupRepository,
                      let payeeRepo = dependencies.payeeRepository else { return }
                vm = SplitGroupDetailViewModel(
                    group: group,
                    splitGroupRepository: splitRepo,
                    payeeRepository: payeeRepo
                )
            }
            await vm?.load()
        }
        .sheet(isPresented: $showAddExpense) {
            if let vm,
               let splitRepo = dependencies.splitGroupRepository {
                AddGroupExpenseView(
                    group: vm.group,
                    memberNames: vm.memberNames,
                    splitGroupRepository: splitRepo
                ) {
                    Task { await vm.load() }
                }
            }
        }
        .sheet(isPresented: $showEditGroup) {
            SplitGroupFormView(existingGroup: group) {
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

    @ViewBuilder
    private func detailContent(_ vm: SplitGroupDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                // Member chips
                memberChips(vm)

                // Simplified balances
                GroupBalanceSummaryCard(
                    balances: vm.simplifiedBalances,
                    memberNames: vm.memberNames
                )

                // Outstanding expenses
                if !vm.outstandingExpenses.isEmpty {
                    expenseSection(
                        title: String(localized: "Outstanding"),
                        expenses: vm.outstandingExpenses,
                        vm: vm
                    )
                }

                // Settled expenses
                if !vm.settledExpenses.isEmpty {
                    expenseSection(
                        title: String(localized: "Settled"),
                        expenses: vm.settledExpenses,
                        vm: vm
                    )
                }

                if vm.expenses.isEmpty {
                    emptyState
                }
            }
            .padding(VSpacing.screenPadding)
        }
    }

    @ViewBuilder
    private func memberChips(_ vm: SplitGroupDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VSpacing.sm) {
                ForEach(vm.group.memberIDs, id: \.self) { id in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(VColors.primary.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text(initials(vm.memberName(for: id)))
                                    .font(VTypography.caption2.bold())
                                    .foregroundStyle(VColors.primary)
                            }
                        Text(vm.memberName(for: id))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                    }
                    .padding(.horizontal, VSpacing.sm)
                    .padding(.vertical, 6)
                    .background(VColors.secondaryBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func expenseSection(title: String, expenses: [GroupExpense], vm: SplitGroupDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(title)
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            VStack(spacing: 0) {
                ForEach(expenses) { expense in
                    GroupExpenseRowView(
                        expense: expense,
                        payerName: vm.memberName(for: expense.paidByMemberID)
                    )
                    .padding(.horizontal, VSpacing.md)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.deleteExpense(expense.id) }
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }

                        if !expense.isSettled {
                            Button {
                                Task { await vm.settleExpense(expense) }
                            } label: {
                                Label(String(localized: "Settle"), systemImage: "checkmark.circle")
                            }
                            .tint(VColors.income)
                        }
                    }

                    if expense.id != expenses.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
            Text(String(localized: "No expenses yet"))
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Add the first shared expense for this group"))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Add Expense")) {
                showAddExpense = true
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }
}
