import SwiftUI
import VittoraCore

private struct ReminderDraft: Identifiable {
    let id = UUID()
    let text: String
}

struct DebtDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: DebtDetailViewModel?
    @State private var showSettlement = false
    @State private var debtToSettle: DebtEntry?
    @State private var debtToDelete: DebtEntry?
    @State private var reminderDraft: ReminderDraft?
    let payeeID: UUID

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm = vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else {
                        balanceSummary(vm)
                        entryList(vm)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.groupedBackground)
        // Deleting money records is not undoable, so it is confirmed and the
        // amount is named in the prompt rather than a bare "Are you sure?".
        .confirmationDialog(
            String(localized: "Delete this debt entry?"),
            isPresented: Binding(
                get: { debtToDelete != nil },
                set: { if !$0 { debtToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let entry = debtToDelete else { return }
                debtToDelete = nil
                Task {
                    await vm?.delete(debtID: entry.id)
                    // The ledger one screen back reloads on this; without it the
                    // deleted entry stayed on screen there until a relaunch.
                    appState.notifyChanged(.debt)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { debtToDelete = nil }
        } message: {
            if let entry = debtToDelete {
                Text(String(localized: "\(CurrencyFormatter.format(entry.amount, currencyCode: currencyCode)) will be removed permanently. This cannot be undone."))
            }
        }
        .navigationTitle(vm?.payee?.name ?? String(localized: "Ledger"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil {
                let settleUC = SettleDebtUseCase(
                    debtRepository: dependencies.debtRepository,
                    accountRepository: dependencies.accountRepository,
                    ledgerWriting: dependencies.ledgerWriteStore
                )
                vm = DebtDetailViewModel(
                    payeeID: payeeID,
                    debtRepository: dependencies.debtRepository,
                    payeeRepository: dependencies.payeeRepository,
                    settleUseCase: settleUC
                )
                await vm?.load()
            }
        }
        .sheet(item: $reminderDraft) { draft in
            ShareSheet(items: [draft.text])
        }
        .sheet(item: $debtToSettle) { debt in
            SettlementFormView(debt: debt) {
                Task { await vm?.load() }
            }
        }
    }

    @ViewBuilder
    private func balanceSummary(_ vm: DebtDetailViewModel) -> some View {
        VStack(spacing: VSpacing.sm) {
            HStack(spacing: VSpacing.xl) {
                balanceColumn(String(localized: "Owed to You"), vm.totalLent, VColors.income)
                Divider()
                balanceColumn(String(localized: "You Owe"), vm.totalBorrowed, VColors.expense)
            }
            Divider()
            HStack {
                Text(String(localized: "Net"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Text(CurrencyFormatter.format(vm.netBalance, currencyCode: currencyCode))
                    .font(VTypography.amountSmall)
                    .amountScaling()
                    .foregroundColor(VColors.textPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Net debt balance"))
            .accessibilityValue(CurrencyFormatter.format(vm.netBalance, currencyCode: currencyCode))
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func balanceColumn(_ title: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(spacing: VSpacing.xs) {
            Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundColor(color)
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(CurrencyFormatter.format(amount, currencyCode: currencyCode))
    }

    @ViewBuilder
    private func entryList(_ vm: DebtDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "History"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            if vm.entries.isEmpty {
                Text(String(localized: "No entries left for this person"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
                    .background(VColors.secondaryGroupedBackground)
                    .cornerRadius(VSpacing.cornerRadiusCard)
            } else {
            VStack(spacing: VSpacing.xs) {
                ForEach(vm.entries) { entry in
                    entryRow(entry, payeeName: vm.payee?.name)
                        .contextMenu {
                            Button(role: .destructive) {
                                debtToDelete = entry
                            } label: {
                                Label(String(localized: "Delete Entry"), systemImage: "trash")
                            }
                        }
                    if entry.id != vm.entries.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            }
        }
    }

    private func reminder(for entry: DebtEntry, payeeName: String?) -> ReminderDraft {
        ReminderDraft(text: DebtContactReminderDraft.message(
            payeeName: payeeName ?? String(localized: "there"),
            remainingAmount: entry.remainingAmount,
            dueDate: entry.dueDate,
            currencyCode: currencyCode
        ))
    }

    @ViewBuilder
    private func entryRow(_ entry: DebtEntry, payeeName: String?) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: entry.direction == .lent ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(entry.direction == .lent ? VColors.income : VColors.expense)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(entry.note ?? (entry.direction == .lent ? String(localized: "Lent") : String(localized: "Borrowed")))
                    .font(VTypography.caption1Bold)
                    .foregroundColor(VColors.textPrimary)
                HStack(spacing: VSpacing.sm) {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textPrimary)
                    if entry.isOverdue {
                        Text(String(localized: "Overdue"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.expense)
                    }
                    if entry.isSettled {
                        Text(String(localized: "Settled"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.income)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                Text(CurrencyFormatter.format(entry.amount, currencyCode: currencyCode))
                    .font(VTypography.amountCaption)
                    .foregroundColor(VColors.textPrimary)
                    .fixedSize(horizontal: true, vertical: true)
                    .accessibilityLabel(String(localized: "Debt amount"))
                    .accessibilityValue(CurrencyFormatter.format(entry.amount, currencyCode: currencyCode))
                if !entry.isSettled && entry.settledAmount > 0 {
                    Text(String(localized: "\(CurrencyFormatter.format(entry.remainingAmount, currencyCode: currencyCode)) left"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textPrimary)
                }
                HStack(spacing: VSpacing.sm) {
                    if !entry.isSettled {
                        if entry.direction == .lent {
                            Button(String(localized: "Remind")) {
                                reminderDraft = reminder(for: entry, payeeName: payeeName)
                            }
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textPrimary)
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        Button(String(localized: "Settle")) {
                            debtToSettle = entry
                        }
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textPrimary)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }

                    // Visible, not only a context menu. The report was that there
                    // is no way to delete an entry, and a long-press users have to
                    // guess at does not answer that. Shown for settled entries too:
                    // a settled entry logged by mistake still needs removing.
                    Button(String(localized: "Delete")) {
                        debtToDelete = entry
                    }
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.expense)
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    // Anchors the audit exemption — see AccessibilityAuditUITests.
                    .accessibilityIdentifier("debt-entry-delete")
                }
            }
        }
        .padding(VSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            entry.note ?? (entry.direction == .lent ? String(localized: "Lent") : String(localized: "Borrowed"))
        )
        .accessibilityValue(
            String(
                localized: "\(CurrencyFormatter.format(entry.amount, currencyCode: currencyCode)), \(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))"
            )
        )
        .accessibilityAction(named: Text(String(localized: "Remind"))) {
            guard entry.direction == .lent, !entry.isSettled else { return }
            reminderDraft = reminder(for: entry, payeeName: payeeName)
        }
        .accessibilityAction(named: Text(String(localized: "Delete"))) {
            debtToDelete = entry
        }
        .accessibilityAction(named: Text(String(localized: "Settle"))) {
            guard !entry.isSettled else { return }
            debtToSettle = entry
        }
    }
}


#Preview {
    NavigationStack {
        DebtDetailView(payeeID: UUID())
    }
}
