#if os(iOS)
import FinanceKit
import FinanceKitUI
import SwiftUI
import VittoraCore

/// Import from Apple Wallet (M3.7.1). Beside "Import CSV" in the
/// Transactions menu, and free like it.
///
/// Consent first: nothing is read until the user allows access. The first
/// import is always chosen — hand-picked with Apple's transaction picker, or
/// the last 30 days after a preview. Automatic import of NEW transactions is a
/// separate switch, off by default.
struct AppleWalletImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openURL) private var openURL
    @Bindable private var service = AppleWalletService.shared
    let onImported: () -> Void

    @State private var pickedTransactions: [FinanceKit.Transaction] = []
    @State private var preview: Preview?
    @State private var result: AppleWalletImportResult?
    @State private var isWorking = false
    @State private var autoImport = AppleWalletService.shared.autoImportEnabledAt != nil
    @State private var error: String?

    /// What an import would do, shown before anything is written.
    struct Preview {
        let records: [WalletTransactionRecord]
        let accounts: [WalletAccountRecord]
        let accepted: [WalletTransactionRecord]
        let skipped: AppleWalletImportResult
    }

    var body: some View {
        NavigationStack {
            Form {
                switch service.availability {
                case .checking:
                    ProgressView()
                case .needsiPhone:
                    message(
                        String(localized: "Use iPhone to import from Apple Wallet"),
                        String(localized: "Apple Card, Apple Cash and Savings transactions can only be read on iPhone. Imported transactions then appear on all your devices."),
                        icon: "iphone"
                    )
                case .unavailable:
                    message(
                        String(localized: "US Apple Wallet only"),
                        String(localized: "Import from Apple Wallet works with Apple Card, Apple Cash and Savings on an iPhone in the US. You can still import transactions from a CSV file."),
                        icon: "wallet.bifold"
                    )
                case .notDetermined:
                    consentSection
                case .denied:
                    deniedSection
                case .authorized:
                    importSections
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Import from Apple Wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .task { await service.refreshAvailability() }
            .onChange(of: pickedTransactions) { _, picked in
                guard !picked.isEmpty else { return }
                Task { await makePreview(picked.map(AppleWalletService.record(from:))) }
            }
            .errorAlert(message: $error)
            .overlay { if isWorking { ProgressView() } }
        }
    }

    // MARK: - States

    private func message(_ title: String, _ detail: String, icon: String) -> some View {
        Section {
            Label(title, systemImage: icon)
                .font(VTypography.bodyBold)
            Text(detail)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("apple-wallet-unavailable")
    }

    private var consentSection: some View {
        Section {
            Label(String(localized: "Apple Card & Cash"), systemImage: "wallet.bifold.fill")
                .font(VTypography.bodyBold)
            Text(String(localized: "Bring Apple Card, Apple Cash and Savings transactions into your Vittora ledger. They're read on this iPhone with your permission — no bank login, and nothing is sent to anyone."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Button {
                Task { await service.requestAuthorization() }
            } label: {
                Text(String(localized: "Allow Access"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
            .accessibilityIdentifier("apple-wallet-allow-button")
        }
    }

    private var deniedSection: some View {
        Section {
            Label(String(localized: "Access is off"), systemImage: "lock")
                .font(VTypography.bodyBold)
            Text(String(localized: "Vittora can't read Apple Wallet transactions. You can allow it in the Settings app under Privacy & Security."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Button(String(localized: "Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
        .accessibilityIdentifier("apple-wallet-denied")
    }

    @ViewBuilder
    private var importSections: some View {
        if let result {
            Section {
                Text(summary(of: result))
                    .accessibilityIdentifier("apple-wallet-result")
            }
        }

        if let preview {
            previewSection(preview)
        } else {
            Section {
                TransactionPicker(selection: $pickedTransactions) {
                    Label(String(localized: "Choose Transactions…"), systemImage: "checklist")
                }
                Button {
                    Task { await loadRecent() }
                } label: {
                    Label(String(localized: "Review Last 30 Days"), systemImage: "calendar")
                }
            } header: {
                VFormSectionHeader(String(localized: "Import"))
            } footer: {
                Text(String(localized: "You see everything before it's added. Transactions already imported are skipped."))
            }
        }

        Section {
            Toggle(String(localized: "Import new transactions automatically"), isOn: $autoImport)
                .onChange(of: autoImport) { _, isOn in service.setAutoImport(isOn) }
                .accessibilityIdentifier("apple-wallet-auto-toggle")
        } footer: {
            Text(String(localized: "Only transactions made after you turn this on, each time you open Vittora. Your edits to imported transactions are never overwritten."))
        }

        Section {
            Button(String(localized: "Stop Apple Wallet Import"), role: .destructive) {
                service.stopImport()
                autoImport = false
            }
        } footer: {
            Text(String(localized: "Imported transactions stay in your ledger. Vittora's access to Apple Wallet is managed in the Settings app."))
        }
    }

    private func previewSection(_ preview: Preview) -> some View {
        Section {
            ForEach(preview.accepted.prefix(50), id: \.id) { record in
                HStack {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(record.merchantName ?? record.description)
                            .lineLimit(1)
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                    Spacer()
                    Text((record.direction == .debit ? -record.amount : record.amount)
                        .formatted(currencyCode: record.currencyCode))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            if preview.accepted.count > 50 {
                Text(String(localized: "and \(preview.accepted.count - 50) more"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            Button {
                Task { await commit(preview) }
            } label: {
                Text(String(localized: "Import \(preview.accepted.count) Transactions"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
            .disabled(preview.accepted.isEmpty || isWorking)
            .accessibilityIdentifier("apple-wallet-import-button")
            Button(String(localized: "Cancel"), role: .cancel) {
                self.preview = nil
                pickedTransactions = []
            }
        } header: {
            VFormSectionHeader(String(localized: "Review"))
        } footer: {
            if let note = skippedNote(preview.skipped) { Text(note) }
        }
    }

    // MARK: - Actions

    private var useCase: ImportAppleWalletTransactionsUseCase { dependencies.makeImportAppleWalletUseCase() }

    private func loadRecent() async {
        isWorking = true
        defer { isWorking = false }
        do {
            await makePreview(try await service.recentTransactions(days: 30))
        } catch {
            self.error = String(localized: "We couldn't read Apple Wallet. Try again in a moment.")
        }
    }

    private func makePreview(_ records: [WalletTransactionRecord]) async {
        do {
            let accounts = try await service.accounts()
            let existing = try await dependencies.transactionRepository.fetchExternalIDs(
                withPrefix: ImportAppleWalletTransactionsUseCase.externalIDPrefix
            )
            let plan = ImportAppleWalletTransactionsUseCase.plan(records, accounts: accounts, existingExternalIDs: existing)
            result = nil
            preview = Preview(records: records, accounts: accounts, accepted: plan.accepted.map(\.record), skipped: plan.result)
        } catch {
            self.error = String(localized: "We couldn't read Apple Wallet. Try again in a moment.")
        }
    }

    private func commit(_ preview: Preview) async {
        isWorking = true
        defer { isWorking = false }
        do {
            result = try await service.importRecords(preview.records, accounts: preview.accounts, using: useCase)
            self.preview = nil
            pickedTransactions = []
            onImported()
        } catch {
            self.error = error.userFacingMessage(fallback: String(localized: "We couldn't import these transactions."))
        }
    }

    // MARK: - Copy

    private func summary(of result: AppleWalletImportResult) -> String {
        var parts = [String(localized: "Imported \(result.importedCount) transactions.")]
        if !result.createdAccountNames.isEmpty {
            parts.append(String(localized: "Added accounts: \(result.createdAccountNames.formatted(.list(type: .and))).")
            )
        }
        if let note = skippedNote(result) { parts.append(note) }
        return parts.joined(separator: " ")
    }

    private func skippedNote(_ result: AppleWalletImportResult) -> String? {
        var parts: [String] = []
        if result.skippedDuplicateCount > 0 {
            parts.append(String(localized: "\(result.skippedDuplicateCount) already imported."))
        }
        if result.skippedPendingCount > 0 {
            parts.append(String(localized: "\(result.skippedPendingCount) still pending — they can be imported once posted."))
        }
        if result.skippedTransferCount > 0 {
            parts.append(String(localized: "\(result.skippedTransferCount) transfers to your other accounts were left out; add them as transfers if you track those accounts."))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
#endif
