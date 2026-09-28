import CloudKit
import SwiftUI
import VittoraCore

/// Household sharing (M3.4.1–3): shared budgets, who spent what, and who may
/// change things. Reached from the Budgets toolbar, and opened automatically
/// when an invitation is accepted.
struct HouseholdView: View {
    @Bindable private var store = HouseholdStore.shared
    @State private var householdName = ""
    @State private var showAddBudget = false
    @State private var confirmsEnding = false

    var body: some View {
        Form {
            if !store.isAvailable {
                unavailableSection
            } else if store.role == .none {
                createSection
            } else {
                summarySection
                budgetsSection
                membersSection
                endSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(store.role == .none ? String(localized: "Household") : store.householdName)
        .toolbar {
            if store.canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add household budget"))
                    .accessibilityIdentifier("household-add-budget-button")
                }
            }
        }
        .refreshable { await store.refresh() }
        .sheet(isPresented: $showAddBudget) {
            HouseholdBudgetFormView()
        }
        // .alert, not a confirmation dialog: DEC-028 — a dialog anchors to a
        // source rect on iPad and landed in the wrong place.
        .alert(
            store.role == .owner
                ? String(localized: "Delete this household?")
                : String(localized: "Leave this household?"),
            isPresented: $confirmsEnding
        ) {
            if store.role == .owner {
                Button(String(localized: "Delete Household"), role: .destructive) {
                    Task { await store.deleteHousehold() }
                }
            } else {
                Button(String(localized: "Leave Household"), role: .destructive) {
                    Task { await store.leaveHousehold() }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(store.role == .owner
                ? String(localized: "Every member loses access, and the household's budgets and expenses are deleted for everyone. This can't be undone.")
                : String(localized: "You'll stop seeing the household's budgets. The owner can invite you again."))
        }
        .errorAlert(message: $store.lastError)
        .overlay {
            if store.isWorking { ProgressView() }
        }
    }

    // MARK: - Sections

    private var unavailableSection: some View {
        Section {
            Label(String(localized: "Household sharing needs iCloud"), systemImage: "icloud.slash")
                .font(VTypography.bodyBold)
            Text(String(localized: "Sign in to iCloud on this device to share budgets with the people you live with."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
        }
    }

    private var createSection: some View {
        Section {
            TextField(String(localized: "Household name"), text: $householdName)
                .accessibilityIdentifier("household-name-field")
            Button {
                let name = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await store.createHousehold(name: name.isEmpty ? String(localized: "Household") : name) }
            } label: {
                Label(String(localized: "Create Household"), systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
            .disabled(store.isWorking)
            .accessibilityIdentifier("household-create-button")
        } header: {
            VFormSectionHeader(String(localized: "Share budgets with your household"))
        } footer: {
            Text(String(localized: "Invite the people you live with to track shared budgets together and see who spent what. Only household budgets are shared — your accounts and transactions stay private."))
        }
    }

    private var summarySection: some View {
        Section {
            if store.canEdit {
                Label(
                    store.role == .owner ? String(localized: "You own this household") : String(localized: "You can make changes"),
                    systemImage: "pencil.circle"
                )
            } else {
                Label(String(localized: "View only"), systemImage: "eye")
                    .accessibilityIdentifier("household-view-only")
                Text(String(localized: "The owner shared this household with you as view only. Ask them for edit access to add expenses."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            if store.role == .owner, let share = store.share {
                ShareLink(
                    item: HouseholdShareItem(share: share),
                    preview: SharePreview(store.householdName)
                ) {
                    Label(String(localized: "Invite or Manage Members"), systemImage: "person.crop.circle.badge.plus")
                }
                .accessibilityIdentifier("household-invite-button")
            }
        }
    }

    private var budgetsSection: some View {
        Section {
            if store.ledger.budgets.isEmpty {
                Text(store.canEdit
                    ? String(localized: "No shared budgets yet. Add one with the + button.")
                    : String(localized: "No shared budgets yet."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            ForEach(store.ledger.budgets) { budget in
                NavigationLink {
                    HouseholdBudgetDetailView(budgetID: budget.id)
                } label: {
                    HouseholdBudgetRow(budget: budget, spent: store.ledger.spent(for: budget))
                }
                .accessibilityIdentifier("household-budget-row")
            }
            .onDelete(perform: store.canEdit ? { offsets in
                offsets.map { store.ledger.budgets[$0] }.forEach(store.deleteBudget)
            } : nil)
        } header: {
            VFormSectionHeader(String(localized: "Shared Budgets"))
        }
    }

    private var membersSection: some View {
        Section {
            ForEach(store.members) { member in
                HStack {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(member.isCurrentUser
                            ? String(localized: "\(member.name) (You)")
                            : member.name)
                        if !member.hasAccepted {
                            Text(String(localized: "Invited"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }
                    Spacer()
                    Text(member.isOwner
                        ? String(localized: "Owner")
                        : member.canEdit ? String(localized: "Can edit") : String(localized: "View only"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            VFormSectionHeader(String(localized: "Members"))
        } footer: {
            if store.role == .owner {
                Text(String(localized: "Choose whether each person can make changes or only view when you invite them. You can change it later from Invite or Manage Members."))
            }
        }
    }

    private var endSection: some View {
        Section {
            Button(role: .destructive) {
                confirmsEnding = true
            } label: {
                Text(store.role == .owner ? String(localized: "Delete Household") : String(localized: "Leave Household"))
            }
            .accessibilityIdentifier("household-end-button")
        }
    }
}

// MARK: - Budget row and detail

private struct HouseholdBudgetRow: View {
    let budget: HouseholdBudget
    let spent: Decimal

    var body: some View {
        let remaining = budget.amount - spent
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack {
                Text(budget.name).font(VTypography.bodyBold)
                Spacer()
                Text(String(localized: "\(spent.formatted(currencyCode: budget.currencyCode)) of \(budget.amount.formatted(currencyCode: budget.currencyCode))"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .monospacedDigit()
            }
            ProgressView(value: HouseholdBudgetRow.fraction(spent: spent, of: budget.amount))
                .tint(remaining < 0 ? VColors.expense : VColors.primary)
            Text(remaining < 0
                ? String(localized: "\((-remaining).formatted(currencyCode: budget.currencyCode)) over")
                : String(localized: "\(remaining.formatted(currencyCode: budget.currencyCode)) left"))
                .font(VTypography.caption1)
                .foregroundStyle(remaining < 0 ? VColors.expense : VColors.textSecondary)
        }
        .padding(.vertical, VSpacing.xxs)
    }

    /// Clamped for the bar only; the text still says how far over it is.
    static func fraction(spent: Decimal, of amount: Decimal) -> Double {
        guard amount > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: spent / amount).doubleValue, 0), 1)
    }
}

private struct HouseholdBudgetDetailView: View {
    @Bindable private var store = HouseholdStore.shared
    let budgetID: String
    @State private var showAddExpense = false

    var body: some View {
        Form {
            if let budget = store.ledger.budgets.first(where: { $0.id == budgetID }) {
                Section {
                    HouseholdBudgetRow(budget: budget, spent: store.ledger.spent(for: budget))
                }

                Section {
                    let totals = store.ledger.memberTotals(for: budget)
                    if totals.isEmpty {
                        Text(String(localized: "Nothing spent this month yet."))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                    ForEach(totals) { member in
                        HStack {
                            Text(member.name.isEmpty ? String(localized: "Household member") : member.name)
                            Spacer()
                            Text(member.total.formatted(currencyCode: budget.currencyCode))
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    VFormSectionHeader(String(localized: "By Member This Month"))
                }

                Section {
                    ForEach(store.ledger.expenses(for: budget)) { expense in
                        let who = expense.memberName.isEmpty ? String(localized: "Household member") : expense.memberName
                        HStack {
                            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                                let day = expense.date.formatted(date: .abbreviated, time: .omitted)
                                Text(expense.note.isEmpty ? who : expense.note)
                                Text(expense.note.isEmpty ? day : String(localized: "\(who) · \(day)"))
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.textSecondary)
                            }
                            Spacer()
                            Text(expense.amount.formatted(currencyCode: budget.currencyCode))
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete(perform: store.canEdit ? { offsets in
                        let items = store.ledger.expenses(for: budget)
                        offsets.map { items[$0] }.forEach(store.deleteExpense)
                    } : nil)
                } header: {
                    VFormSectionHeader(String(localized: "Expenses This Month"))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(store.ledger.budgets.first { $0.id == budgetID }?.name ?? String(localized: "Household"))
        .toolbar {
            if store.canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add household expense"))
                    .accessibilityIdentifier("household-add-expense-button")
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            if let budget = store.ledger.budgets.first(where: { $0.id == budgetID }) {
                HouseholdExpenseFormView(budget: budget)
            }
        }
    }
}

// MARK: - Forms

private struct HouseholdBudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @State private var name = ""
    @State private var amountText = ""
    @FocusState private var nameFocused: Bool

    private var amount: Decimal? {
        Decimal(localizedAmount: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Name (e.g. Groceries)"), text: $name)
                    .focused($nameFocused)
                    .onAppear { nameFocused = true }
                TextField(String(localized: "Monthly amount"), text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "New Shared Budget"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        guard let amount else { return }
                        HouseholdStore.shared.addBudget(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            amount: amount,
                            currencyCode: currencyCode
                        )
                        dismiss()
                    }
                    .disabled(amount == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct HouseholdExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    let budget: HouseholdBudget
    @State private var amountText = ""
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    private var amount: Decimal? {
        Decimal(localizedAmount: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Amount"), text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused($amountFocused)
                    .onAppear { amountFocused = true }
                TextField(String(localized: "Note (optional)"), text: $note)
            }
            .formStyle(.grouped)
            .navigationTitle(budget.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        guard let amount else { return }
                        HouseholdStore.shared.addExpense(
                            to: budget,
                            amount: amount,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
        }
    }
}

// MARK: - Sharing

/// The household's share, handed to the system share sheet. `.existing`
/// because the share is created with the household — the same sheet then
/// offers both inviting and managing who can edit.
nonisolated struct HouseholdShareItem: Transferable {
    let share: CKShare

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { item in
            .existing(
                item.share,
                container: CKContainer(identifier: HouseholdStore.containerIdentifier),
                // M3.4.3: the owner picks "Can make changes" or "View only"
                // per person. Invite-only — never anyone with the link.
                allowedSharingOptions: CKAllowedSharingOptions(
                    allowedParticipantPermissionOptions: .any,
                    allowedParticipantAccessOptions: .specifiedRecipientsOnly
                )
            )
        }
    }
}

extension View {
    /// Opens the household when an invitation has just been accepted, so the
    /// person who tapped the link lands on what they joined.
    func householdInvitationSheet() -> some View {
        modifier(HouseholdInvitationSheet())
    }
}

private struct HouseholdInvitationSheet: ViewModifier {
    @Bindable private var store = HouseholdStore.shared

    func body(content: Content) -> some View {
        content.sheet(isPresented: $store.presentsHousehold) {
            NavigationStack {
                HouseholdView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Done")) { store.presentsHousehold = false }
                        }
                    }
            }
        }
    }
}
