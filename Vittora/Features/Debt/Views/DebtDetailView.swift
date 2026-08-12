import SwiftUI
import VittoraCore

struct DebtDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: DebtDetailViewModel?
    @State private var showSettlement = false
    @State private var debtToSettle: DebtEntry?
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

            VStack(spacing: VSpacing.xs) {
                ForEach(vm.entries) { entry in
                    entryRow(entry, payeeName: vm.payee?.name)
                    if entry.id != vm.entries.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
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
                if !entry.isSettled {
                    HStack(spacing: VSpacing.sm) {
                        if entry.direction == .lent {
                            ShareLink(
                                item: DebtContactReminderDraft.message(
                                    payeeName: payeeName ?? String(localized: "there"),
                                    remainingAmount: entry.remainingAmount,
                                    dueDate: entry.dueDate,
                                    currencyCode: currencyCode
                                )
                            ) {
                                Text(String(localized: "Remind"))
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textPrimary)
                            }
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
    }
}


#Preview {
    NavigationStack {
        DebtDetailView(payeeID: UUID())
    }
}
