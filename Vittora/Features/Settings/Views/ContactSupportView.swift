import SwiftUI
import VittoraCore
#if os(iOS)
import UIKit
#if canImport(MessageUI)
import MessageUI
#endif
#elseif os(macOS)
import AppKit
#endif

/// Builds the counts-only diagnostic snapshot shown on Contact Support.
@MainActor
enum DiagnosticSnapshotBuilder {
    static func make(
        settingsVM: SettingsViewModel,
        stats: DatabaseStats,
        payeeCount: Int,
        recurringRuleCount: Int,
        syncState: SyncState? = nil,
        lastSyncDate: Date? = nil,
        errorLog: RecentErrorLogStore = .shared
    ) -> DiagnosticSnapshot {
        let syncEnabled = settingsVM.isCloudSyncEnabled
        let resolvedLastSync = lastSyncDate
            ?? (AppUserDefaults.sync.object(forKey: AppUserDefaults.SyncKey.lastSyncDate) as? Date)
        let lastSyncResult: String
        if !syncEnabled {
            lastSyncResult = "disabled"
        } else if let syncState {
            switch syncState {
            case .synced:
                if let date = resolvedLastSync {
                    lastSyncResult = "synced (\(date.formatted(date: .abbreviated, time: .shortened)))"
                } else {
                    lastSyncResult = "synced (never)"
                }
            case .syncing:
                lastSyncResult = "syncing"
            case .pending:
                lastSyncResult = "pending"
            case .offline:
                lastSyncResult = "offline"
            case .error:
                lastSyncResult = "error"
            }
        } else if let date = resolvedLastSync {
            lastSyncResult = "synced (\(date.formatted(date: .abbreviated, time: .shortened)))"
        } else {
            lastSyncResult = "enabled (never synced)"
        }

        #if os(iOS)
        let osName = "iOS"
        #elseif os(macOS)
        let osName = "macOS"
        #else
        let osName = "Unknown"
        #endif

        return DiagnosticSnapshot(
            appVersion: settingsVM.appVersion,
            buildNumber: settingsVM.buildNumber,
            osName: osName,
            osVersion: DiagnosticDeviceInfo.osVersionString,
            deviceModel: DiagnosticDeviceInfo.hardwareModel,
            localeIdentifier: Locale.current.identifier,
            currencyCode: settingsVM.selectedCurrencyCode,
            cloudSyncEnabled: syncEnabled,
            lastSyncResult: lastSyncResult,
            transactionCount: stats.transactionCount,
            accountCount: stats.accountCount,
            categoryCount: stats.categoryCount,
            budgetCount: stats.budgetCount,
            debtCount: stats.debtCount,
            savingsGoalCount: stats.savingsGoalCount,
            splitGroupCount: stats.splitGroupCount,
            documentCount: stats.documentCount,
            payeeCount: payeeCount,
            recurringRuleCount: recurringRuleCount,
            recentErrors: errorLog.recentEntries()
        )
    }
}

struct ContactSupportView: View {
    let settingsVM: SettingsViewModel
    let dependencies: DependencyContainer
    var syncService: SyncStatusService?
    @Environment(\.openURL) private var openURL

    @State private var payloadText = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showMailComposer = false
    @State private var showCopiedAlert = false
    @State private var showNoMailAlert = false
    @State private var showClearedAlert = false

    var body: some View {
        Form {
            Section {
                Text(String(localized: "Describe your issue in email. A diagnostic summary is included so we can help — you can edit or remove it before sending."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityIdentifier("contact-support-intro")
            }

            Section {
                if let supportURL = DiagnosticPayload.supportURL {
                    Link(destination: supportURL) {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .blue,
                            title: String(localized: "FAQ & Troubleshooting"),
                            value: ""
                        )
                    }
                    .accessibilityIdentifier("contact-support-faq")
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(String(localized: "Loading diagnostics"))
                } else if let loadError {
                    VInlineErrorText(loadError)
                } else {
                    Text(String(localized: "This is everything that will be included."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .accessibilityIdentifier("contact-support-payload-disclaimer")

                    ScrollView {
                        Text(payloadText)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, VSpacing.sm)
                    }
                    .frame(minHeight: 220, maxHeight: 360)
                    .accessibilityIdentifier("contact-support-payload")
                    .accessibilityLabel(String(localized: "Diagnostic summary"))
                    .accessibilityValue(payloadText)
                }
            } header: {
                Text(String(localized: "Diagnostic Summary"))
            }

            Section {
                Button {
                    sendSupportEmail()
                } label: {
                    SettingsRow(
                        icon: "envelope.fill",
                        iconColor: .green,
                        title: String(localized: "Send Email"),
                        value: ""
                    )
                }
                .disabled(isLoading || payloadText.isEmpty)
                .accessibilityIdentifier("contact-support-send")

                Button {
                    copyPayloadToClipboard()
                    showCopiedAlert = true
                } label: {
                    SettingsRow(
                        icon: "doc.on.doc.fill",
                        iconColor: .gray,
                        title: String(localized: "Copy Diagnostics"),
                        value: ""
                    )
                }
                .disabled(isLoading || payloadText.isEmpty)
                .accessibilityIdentifier("contact-support-copy")

                Button(role: .destructive) {
                    RecentErrorLogStore.shared.clear()
                    Task { await reloadPayload() }
                    showClearedAlert = true
                } label: {
                    SettingsRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: String(localized: "Clear Recent Errors"),
                        value: ""
                    )
                }
                .accessibilityIdentifier("contact-support-clear-errors")
            } footer: {
                Text(String(localized: "Nothing is sent automatically. Email goes through your own mail app, which you can edit or cancel."))
                    .foregroundStyle(VColors.textSecondary)
            }
        }
        .navigationTitle(String(localized: "Contact Support"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await reloadPayload() }
        .alert(String(localized: "Copied"), isPresented: $showCopiedAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Diagnostics copied to the clipboard."))
        }
        .alert(String(localized: "Mail Not Configured"), isPresented: $showNoMailAlert) {
            Button(String(localized: "Copy Diagnostics")) {
                copyPayloadToClipboard()
                showCopiedAlert = true
            }
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(
                String(
                    localized: "No mail account is set up on this device. Copy the diagnostics and email \(DiagnosticPayload.supportEmail) from another app."
                )
            )
        }
        .alert(String(localized: "Recent Errors Cleared"), isPresented: $showClearedAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        }
        #if canImport(MessageUI) && os(iOS)
        .sheet(isPresented: $showMailComposer) {
            SupportMailComposeView(
                recipient: DiagnosticPayload.supportEmail,
                subject: String(localized: "Vittora Support"),
                body: mailBody,
                isPresented: $showMailComposer
            )
        }
        #endif
    }

    private var mailBody: String {
        """
        \(String(localized: "Please describe what happened:"))


        ---
        \(payloadText)
        """
    }

    private func sendSupportEmail() {
        #if canImport(MessageUI) && os(iOS)
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
            return
        }
        #endif
        if let url = mailtoURL() {
            openURL(url) { accepted in
                if !accepted {
                    showNoMailAlert = true
                }
            }
        } else {
            showNoMailAlert = true
        }
    }

    private func mailtoURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = DiagnosticPayload.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "Vittora Support")),
            URLQueryItem(name: "body", value: mailBody),
        ]
        return components.url
    }

    private func copyPayloadToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = payloadText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payloadText, forType: .string)
        #endif
    }

    private func reloadPayload() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let service = dependencies.makeDataManagementService()
            let stats = try await service.fetchStats()
            let payeeCount = try await dependencies.payeeRepository.fetchAll().count
            let recurringCount = try await dependencies.recurringRuleRepository.fetchAll().count
            let snapshot = DiagnosticSnapshotBuilder.make(
                settingsVM: settingsVM,
                stats: stats,
                payeeCount: payeeCount,
                recurringRuleCount: recurringCount,
                syncState: syncService?.syncState,
                lastSyncDate: syncService?.lastSyncDate
            )
            payloadText = DiagnosticPayload.render(snapshot)
        } catch {
            loadError = error.localizedDescription
            RecentErrorLogStore.shared.record(
                errorType: String(describing: type(of: error)),
                codePath: "ContactSupportView.reloadPayload"
            )
        }
    }
}

#if canImport(MessageUI) && os(iOS)
private struct SupportMailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            isPresented = false
        }
    }
}
#endif
