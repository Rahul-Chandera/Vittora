import SwiftUI
import VittoraCore

struct TransactionDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: TransactionDetailViewModel?
    let transactionID: UUID
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            if let vm = vm, let transaction = vm.transaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: VSpacing.lg) {
                        // Amount display — textPrimary on the card surface.
                        // Semantic income/expense hues fail AA as large XL text
                        // on secondaryBackground (and trip Apple's sampler).
                        VStack(spacing: VSpacing.sm) {
                            HStack(spacing: VSpacing.sm) {
                                Text(CurrencyFormatter.format(transaction.amount, currencyCode: currencyCode))
                                    .font(VTypography.title1)
                                    .foregroundColor(VColors.textPrimary)

                                Image(systemName: typeIcon(for: transaction.type))
                                    .font(.title3)
                                    .foregroundColor(VColors.textPrimary)
                            }

                            HStack(spacing: VSpacing.md) {
                                Text(transaction.type.displayName)
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textPrimary)
                                    .padding(.horizontal, VSpacing.md)
                                    .padding(.vertical, VSpacing.xs)
                                    .background(VColors.tertiaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusSM)

                                Text(formatDate(transaction.date))
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textPrimary)

                                Spacer()
                            }
                        }
                        .padding(VSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                                .fill(VColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                                        .strokeBorder(VColors.textTertiary.opacity(0.35), lineWidth: 1)
                                )
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "Transaction summary"))
                        .accessibilityValue(
                            String(
                                localized: "\(transaction.type.displayName), \(CurrencyFormatter.format(transaction.amount, currencyCode: currencyCode)), \(formatDate(transaction.date))"
                            )
                        )

                        // Attachments before metadata so the documents audit can
                        // bring Attachments on-screen at XL without parking Note /
                        // Tags under the large-title nav chrome (which fails the
                        // contrast sampler against liquid-glass material).
                        DocumentListView(transactionID: transactionID)
                            .padding(.horizontal, VSpacing.lg)

                        // Details section
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            if let note = transaction.note, !note.isEmpty {
                                detailRow(label: String(localized: "Note"), value: note)
                            }

                            if !transaction.tags.isEmpty {
                                VStack(alignment: .leading, spacing: VSpacing.sm) {
                                    Text(String(localized: "Tags"))
                                        .font(VTypography.bodyBold)
                                        .foregroundColor(VColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    HStack(spacing: VSpacing.sm) {
                                        ForEach(transaction.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(VTypography.body)
                                                .foregroundColor(VColors.textPrimary)
                                                .padding(.horizontal, VSpacing.sm)
                                                .padding(.vertical, VSpacing.xs)
                                                .background(VColors.tertiaryBackground)
                                                .cornerRadius(VSpacing.cornerRadiusSM)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                    }
                                }
                            }

                            detailRow(label: String(localized: "Payment Method"), value: transaction.paymentMethod.displayName)
                        }
                        .padding(VSpacing.lg)

                        if !vm.editHistory.isEmpty {
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text(String(localized: "Edit History"))
                                    .font(VTypography.bodyBold)
                                    .foregroundColor(VColors.textPrimary)

                                ForEach(vm.editHistory) { record in
                                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                                        Text(record.editedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(VTypography.caption2)
                                            .foregroundColor(VColors.textPrimary)

                                        ForEach(record.changes, id: \.field) { change in
                                            Text(
                                                String(
                                                    localized: "\(editFieldLabel(change.field)): \(displayEditValue(change.previousValue, field: change.field, currencyCode: currencyCode)) → \(displayEditValue(change.newValue, field: change.field, currencyCode: currencyCode))"
                                                )
                                            )
                                            .font(VTypography.caption1)
                                            .foregroundColor(VColors.textPrimary)
                                        }
                                    }
                                    .padding(VSpacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(VColors.secondaryGroupedBackground)
                                    .cornerRadius(VSpacing.cornerRadiusSM)
                                }
                            }
                            .padding(.horizontal, VSpacing.lg)
                        }

                        // Related transactions
                        if !vm.relatedTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text(String(localized: "Similar Transactions"))
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
                                                        .foregroundColor(VColors.textPrimary)
                                                }

                                                Spacer()

                                                Text(CurrencyFormatter.format(related.amount, currencyCode: currencyCode))
                                                    .font(VTypography.caption1)
                                                    .foregroundColor(VColors.textPrimary)
                                            }
                                            .padding(VSpacing.md)
                                            .background(VColors.secondaryGroupedBackground)
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
                // Grouped page like every other screen (owner decision
                // 2026-08-09). This screen had no page paint at all — it relied
                // on the system default white — so colouring only the clearance
                // strip grey put a visible band across the content.
                .background(VColors.groupedBackground)
                // safeAreaPadding, not safeAreaInset: a stack of cards, and an
                // opaque inset paints OVER the last one, slicing it mid-glyph.
                .safeAreaPadding(.bottom, dynamicTypeSize.isAccessibilitySize ? 140 : 72)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: VSpacing.md) {
                            Button {
                                showEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityIdentifier("transaction-detail-edit-button")
                            .accessibilityLabel(String(localized: "Edit transaction"))
                            .accessibilityHint(String(localized: "Opens the transaction form"))

                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await vm.delete()
                                        appState.notifyChanged([.transactions, .accounts, .budgets])
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
                        .font(.system(.largeTitle))
                        .foregroundColor(VColors.textSecondary)
                        .accessibilityHidden(true)

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
        .accessibilityIdentifier("transaction-detail-root")
        .advertisesHandoff(.transactionDetail(transactionID))
        .errorAlert(message: transactionDetailErrorBinding)
        .task {
            if vm == nil {
                vm = createViewModel()
                await vm?.loadTransaction(id: transactionID)
            }
        }
        // Edit as a sheet (like Account/Payee detail): a push via
        // navigationDestination silently fails inside the iPad split view's
        // detail column, and the sheet works identically on iPhone.
        .sheet(isPresented: $showEditSheet, onDismiss: {
            Task { await vm?.loadTransaction(id: transactionID) }
        }) {
            NavigationStack {
                TransactionFormView(transactionID: transactionID, showsCancelButton: true)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(label)
                .font(VTypography.bodyBold)
                .foregroundColor(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(VTypography.body)
                .foregroundColor(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func editFieldLabel(_ field: TransactionEditField) -> String {
        switch field {
        case .amount: String(localized: "Amount")
        case .date: String(localized: "Date")
        case .type: String(localized: "Type")
        case .category: String(localized: "Category")
        case .account: String(localized: "Account")
        case .payee: String(localized: "Payee")
        case .note: String(localized: "Note")
        case .tags: String(localized: "Tags")
        case .paymentMethod: String(localized: "Payment Method")
        }
    }

    private func displayEditValue(
        _ raw: String?,
        field: TransactionEditField,
        currencyCode: String
    ) -> String {
        guard let raw, !raw.isEmpty else {
            return String(localized: "—")
        }
        switch field {
        case .amount:
            if let decimal = Decimal(string: raw) {
                return CurrencyFormatter.format(decimal, currencyCode: currencyCode)
            }
            return raw
        case .type, .paymentMethod:
            if let type = TransactionType(rawValue: raw) {
                return type.displayName
            }
            if let method = PaymentMethod(rawValue: raw) {
                return method.displayName
            }
            return raw
        case .date:
            if let date = ISO8601DateFormatter().date(from: raw) {
                return formatDate(date)
            }
            return raw
        default:
            return raw
        }
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
            // On-surface, not the fill: this colours the amount TEXT and the
            // type label on a card. The fill accent is solved to carry white
            // content on top of it, and with the purple accent on the OLED
            // card it measures 3.35:1 against the 4.5:1 body-text minimum.
            return VColors.primaryOnSurface
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

    private func createViewModel() -> TransactionDetailViewModel {
        dependencies.makeTransactionDetailViewModel()
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
