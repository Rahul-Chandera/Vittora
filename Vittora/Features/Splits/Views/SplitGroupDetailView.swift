import SwiftUI
import VittoraCore

struct SplitGroupDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: SplitGroupDetailViewModel?
    @State private var showAddExpense = false
    @State private var showEditGroup = false
    /// Staged by the delete action so the confirmation can name the expense.
    @State private var expenseToDelete: GroupExpense?

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
        // Fill first, then paint — a ZStack sizes to its child, so the page
        // colour would only cover the empty/loading state's own height and
        // leave the system default white above and below it.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
        .navigationTitle(group.name)
        .confirmationDialog(
            String(localized: "Delete this expense?"),
            isPresented: Binding(
                get: { expenseToDelete != nil },
                set: { if !$0 { expenseToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let expense = expenseToDelete, let vm else { return }
                expenseToDelete = nil
                Task { await vm.deleteExpense(expense.id) }
            }
            Button(String(localized: "Cancel"), role: .cancel) { expenseToDelete = nil }
        } message: {
            if let expense = expenseToDelete {
                Text(String(localized: "\(expense.title) will be removed from this group and everyone's share recalculated. This cannot be undone."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add group expense"))
                .accessibilityHint(String(localized: "Opens the group expense form"))
                .accessibilityIdentifier("split-expense-add-button")
                .foregroundStyle(VColors.textPrimary)
            }
            if let vm {
                ToolbarItem(placement: .automatic) {
                    shareMenu(vm)
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
                vm = SplitGroupDetailViewModel(
                    group: group,
                    splitGroupRepository: dependencies.splitGroupRepository,
                    payeeRepository: dependencies.payeeRepository
                )
            }
            await vm?.load()
        }
        .sheet(isPresented: $showAddExpense) {
            if let vm {
                AddGroupExpenseView(
                    group: vm.group,
                    memberNames: vm.memberNames,
                    splitGroupRepository: dependencies.splitGroupRepository
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
                        ZStack {
                            // Avatar disc, a fill on a surface — not a card
                            // on the page — so it keeps secondaryBackground.
                            Circle()
                                .fill(VColors.secondaryBackground)
                                .frame(width: 28, height: 28)
                            Text(initials(vm.memberName(for: id)))
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.textPrimary)
                        }
                        .accessibilityHidden(true)
                        Text(vm.memberName(for: id))
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                    }
                    .padding(.horizontal, VSpacing.sm)
                    .padding(.vertical, 6)
                    .background(VColors.secondaryGroupedBackground)
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
                    // These rows are in a ScrollView, not a List, so the
                    // .swipeActions below never fire on either platform —
                    // deleting or settling a group expense had no reachable
                    // path at all. The menu is the one that actually works;
                    // the swipe actions stay for if this ever becomes a List.
                    .contextMenu {
                        if !expense.isSettled {
                            Button {
                                Task { await vm.settleExpense(expense) }
                            } label: {
                                Label(String(localized: "Settle"), systemImage: "checkmark.circle")
                            }
                        }
                        Button(role: .destructive) {
                            expenseToDelete = expense
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            expenseToDelete = expense
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
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "cart.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityHidden(true)
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

    @ViewBuilder
    private func shareMenu(_ vm: SplitGroupDetailViewModel) -> some View {
        Menu {
            ShareLink(
                item: SplitGroupShareDraft.inviteMessage(
                    groupName: vm.group.name,
                    memberNames: vm.memberNames,
                    memberIDs: vm.group.memberIDs,
                    balances: vm.simplifiedBalances,
                    groupID: vm.group.id,
                    currencyCode: currencyCode
                )
            ) {
                Label(String(localized: "Invite to Group"), systemImage: "person.badge.plus")
            }

            ShareLink(
                item: SplitGroupShareDraft.summaryMessage(
                    groupName: vm.group.name,
                    memberNames: vm.memberNames,
                    memberIDs: vm.group.memberIDs,
                    balances: vm.simplifiedBalances,
                    outstandingExpenses: vm.outstandingExpenses,
                    currencyCode: currencyCode
                )
            ) {
                Label(String(localized: "Share Summary"), systemImage: "square.and.arrow.up")
            }

            ReportPDFShareLink(
                fileName: "split-group-\(vm.group.name)",
                contentVersion: vm.exportContentVersion,
                isEnabled: !vm.isLoading
            ) {
                SplitGroupExportDocument(
                    groupName: vm.group.name,
                    memberNames: vm.memberNames,
                    memberIDs: vm.group.memberIDs,
                    balances: vm.simplifiedBalances,
                    outstandingExpenses: vm.outstandingExpenses,
                    settledExpenses: vm.settledExpenses,
                    currencyCode: currencyCode
                )
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }
    }
}
