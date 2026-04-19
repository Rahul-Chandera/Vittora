import SwiftUI

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
        .background(VColors.background)
        .navigationTitle(vm?.payee?.name ?? String(localized: "Ledger"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil {
                guard let debtRepo = dependencies.debtRepository,
                      let payeeRepo = dependencies.payeeRepository,
                      let txRepo = dependencies.transactionRepository,
                      let accRepo = dependencies.accountRepository else { return }
                let settleUC = SettleDebtUseCase(
                    debtRepository: debtRepo,
                    transactionRepository: txRepo,
                    accountRepository: accRepo
                )
                vm = DebtDetailViewModel(
                    payeeID: payeeID,
                    debtRepository: debtRepo,
                    payeeRepository: payeeRepo,
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
                Text(formattedAmount(vm.netBalance))
                    .font(VTypography.amountSmall)
                    .foregroundColor(vm.netBalance >= 0 ? VColors.income : VColors.expense)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func balanceColumn(_ title: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(spacing: VSpacing.xs) {
            Text(formattedAmount(amount))
                .font(VTypography.amountMedium)
                .foregroundColor(color)
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func entryList(_ vm: DebtDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "History"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            VStack(spacing: VSpacing.xs) {
                ForEach(vm.entries) { entry in
                    entryRow(entry)
                    if entry.id != vm.entries.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: DebtEntry) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: entry.direction == .lent ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(entry.direction == .lent ? VColors.income : VColors.expense)
                .font(.title3)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(entry.note ?? (entry.direction == .lent ? String(localized: "Lent") : String(localized: "Borrowed")))
                    .font(VTypography.caption1Bold)
                    .foregroundColor(VColors.textPrimary)
                HStack(spacing: VSpacing.sm) {
                    Text(entry.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
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
                Text(formattedAmount(entry.amount))
                    .font(VTypography.amountCaption)
                    .foregroundColor(VColors.textPrimary)
                if !entry.isSettled && entry.settledAmount > 0 {
                    Text(String(localized: "\(formattedAmount(entry.remainingAmount)) left"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textSecondary)
                }
                if !entry.isSettled {
                    Button(String(localized: "Settle")) {
                        debtToSettle = entry
                    }
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.primary)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(VSpacing.md)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
}


#Preview {
    NavigationStack {
        DebtDetailView(payeeID: UUID())
    }
}
