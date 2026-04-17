import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TransactionDetailViewModel?
    let transactionID: UUID
    @State private var navigateDestination: NavigationDestination?

    var body: some View {
        ZStack {
            if let vm = vm, let transaction = vm.transaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: VSpacing.lg) {
                        // Amount display
                        VStack(spacing: VSpacing.sm) {
                            let amountColor = transactionColor(for: transaction.type)
                            HStack(spacing: VSpacing.sm) {
                                Text(formatAmount(transaction.amount))
                                    .font(VTypography.title1)
                                    .foregroundColor(amountColor)

                                Image(systemName: typeIcon(for: transaction.type))
                                    .font(.title3)
                                    .foregroundColor(amountColor)
                            }

                            HStack(spacing: VSpacing.md) {
                                Text(transaction.type.rawValue.capitalized)
                                    .font(VTypography.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, VSpacing.md)
                                    .padding(.vertical, VSpacing.xs)
                                    .background(amountColor)
                                    .cornerRadius(VSpacing.cornerRadiusSM)

                                Text(formatDate(transaction.date))
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)

                                Spacer()
                            }
                        }
                        .padding(VSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusSM)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "Transaction summary"))
                        .accessibilityValue(
                            String(
                                localized: "\(transaction.type.rawValue.capitalized), \(formatAmount(transaction.amount)), \(formatDate(transaction.date))"
                            )
                        )

                        // Details section
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            if let note = transaction.note, !note.isEmpty {
                                detailRow(label: "Note", value: note)
                            }

                            if !transaction.tags.isEmpty {
                                VStack(alignment: .leading, spacing: VSpacing.sm) {
                                    Text("Tags")
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textSecondary)

                                    HStack(spacing: VSpacing.sm) {
                                        ForEach(transaction.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(VTypography.caption1)
                                                .foregroundColor(VColors.primary)
                                                .padding(.horizontal, VSpacing.sm)
                                                .padding(.vertical, VSpacing.xs)
                                                .background(VColors.primary.opacity(0.1))
                                                .cornerRadius(VSpacing.cornerRadiusSM)
                                        }
                                        Spacer()
                                    }
                                }
                            }

                            detailRow(label: "Payment Method", value: transaction.paymentMethod.rawValue.capitalized)
                        }
                        .padding(VSpacing.lg)

                        // Related transactions
                        if !vm.relatedTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text("Similar Transactions")
                                    .font(VTypography.bodyBold)
                                    .foregroundColor(VColors.textPrimary)

                                VStack(spacing: VSpacing.sm) {
                                    ForEach(vm.relatedTransactions.prefix(5)) { related in
                                        NavigationLink(value: NavigationDestination.transactionDetail(id: related.id)) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                                    Text(related.note ?? "Transaction")
                                                        .font(VTypography.caption1)
                                                        .foregroundColor(VColors.textPrimary)

                                                    Text(formatDate(related.date))
                                                        .font(VTypography.caption2)
                                                        .foregroundColor(VColors.textSecondary)
                                                }

                                                Spacer()

                                                Text(formatAmount(related.amount))
                                                    .font(VTypography.caption1)
                                                    .foregroundColor(transactionColor(for: related.type))
                                            }
                                            .padding(VSpacing.md)
                                            .background(VColors.secondaryBackground)
                                            .cornerRadius(VSpacing.cornerRadiusSM)
                                        }
                                    }
                                }
                            }
                            .padding(VSpacing.lg)
                        }

                        Spacer()
                    }
                    .padding(VSpacing.screenPadding)
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: VSpacing.md) {
                            NavigationLink(value: NavigationDestination.editTransaction(id: transaction.id)) {
                                Image(systemName: "pencil")
                            }
                            .accessibilityIdentifier("transaction-detail-edit-button")
                            .accessibilityLabel(String(localized: "Edit transaction"))
                            .accessibilityHint(String(localized: "Opens the transaction form"))

                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await vm.delete()
                                        dismiss()
                                    } catch {
                                        vm.error = error.userFacingMessage(
                                            fallback: String(localized: "We couldn't delete this transaction.")
                                        )
                                    }
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityIdentifier("transaction-detail-delete-button")
                            .accessibilityLabel(String(localized: "Delete transaction"))
                            .accessibilityHint(String(localized: "Deletes this transaction"))
                        }
                    }
                }
            } else if let vm = vm, vm.isLoading {
                ProgressView()
                    .tint(VColors.primary)
            } else if let vm = vm {
                VStack(spacing: VSpacing.lg) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(VColors.textSecondary)

                    Text(String(localized: "Transaction unavailable"))
                        .font(VTypography.title3)
                        .foregroundColor(VColors.textPrimary)

                    Text(vm.error ?? String(localized: "This transaction could not be loaded."))
                        .font(VTypography.callout)
                        .foregroundColor(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(VSpacing.lg)
            }
        }
        .errorAlert(message: transactionDetailErrorBinding)
        .task {
            if vm == nil {
                vm = await createViewModel()
                await vm?.loadTransaction(id: transactionID)
            }
        }
        .navigationDestination(item: $navigateDestination) { dest in
            navigationView(for: dest)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(label)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)

            Text(value)
                .font(VTypography.body)
                .foregroundColor(VColors.textPrimary)
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func transactionColor(for type: TransactionType) -> Color {
        switch type {
        case .expense:
            return VColors.expense
        case .income:
            return VColors.income
        case .transfer:
            return VColors.transfer
        case .adjustment:
            return VColors.primary
        }
    }

    private func typeIcon(for type: TransactionType) -> String {
        switch type {
        case .expense:
            return "arrow.down"
        case .income:
            return "arrow.up"
        case .transfer:
            return "arrow.left.arrow.right"
        case .adjustment:
            return "equal"
        }
    }

    @ViewBuilder
    private func navigationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .transactionDetail(let id):
            TransactionDetailView(transactionID: id)

        case .editTransaction(let id):
            TransactionFormView(transactionID: id)

        default:
            EmptyView()
        }
    }

    private func createViewModel() async -> TransactionDetailViewModel? {
        guard let transactionRepo = dependencies.transactionRepository,
              let accountRepo = dependencies.accountRepository else {
            return nil
        }

        let fetchUseCase = FetchTransactionsUseCase(transactionRepository: transactionRepo)
        let deleteUseCase = DeleteTransactionUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo
        )

        return TransactionDetailViewModel(
            fetchUseCase: fetchUseCase,
            deleteUseCase: deleteUseCase
        )
    }

    private var transactionDetailErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(transactionID: UUID())
    }
}
