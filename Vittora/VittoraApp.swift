//
//  VittoraApp.swift
//  Vittora
//
//  Created by Rahul on 12/04/26.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct VittoraApp: App {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "startup")

    @State private var appState: AppState
    @State private var router: Router
    @State private var dependencies: DependencyContainer
    @State private var settingsVM: SettingsViewModel
    @State private var syncService: SyncStatusService
    @State private var syncConflictHandler: SyncConflictHandler
    @State private var cloudKitSyncMonitor: CloudKitSyncMonitor?
    @State private var hasCompletedStartup = false
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer?
    private let isUITesting: Bool
    private let isRunningAutomatedTests: Bool
    private let showsOnboardingForUITesting: Bool
    private let bypassOnboardingForUITesting: Bool
    private let seedsTransactionsForUITesting: Bool
    private let seedsTransfersForUITesting: Bool
    private let startupErrorMessage: String?
    private let startupFailureMessage: String?
    private let recurringGenerationUseCase: GenerateRecurringTransactionsUseCase?

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        isUITesting = launchArguments.contains("--uitesting")
        isRunningAutomatedTests = isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        showsOnboardingForUITesting = launchArguments.contains("--ui-test-onboarding")
        bypassOnboardingForUITesting = isUITesting && !showsOnboardingForUITesting
        seedsTransactionsForUITesting = launchArguments.contains("--ui-test-seed-transactions")
        seedsTransfersForUITesting = launchArguments.contains("--ui-test-seed-transfers")

        let startupContainer = Self.makeStartupModelContainer(inMemory: isRunningAutomatedTests)
        modelContainer = startupContainer.container
        startupErrorMessage = startupContainer.errorMessage
        startupFailureMessage = startupContainer.failureMessage

        let dependencyContainer: DependencyContainer
        if let modelContainer {
            dependencyContainer = DependencyContainer.createDefault(modelContainer: modelContainer)
        } else {
            dependencyContainer = DependencyContainer()
        }
        let syncStatusService = SyncStatusService(isMonitoringEnabled: !isRunningAutomatedTests)
        let conflictHandler = SyncConflictHandler(
            auditLogger: dependencyContainer.securityAuditLogService
        )
        _dependencies = State(initialValue: dependencyContainer)
        _router = State(initialValue: Router())
        let keychainService = dependencyContainer.keychainService ?? KeychainService()
        _settingsVM = State(initialValue: SettingsViewModel(keychainService: keychainService))
        _syncService = State(initialValue: syncStatusService)
        _syncConflictHandler = State(initialValue: conflictHandler)
        _cloudKitSyncMonitor = State(
            initialValue: isRunningAutomatedTests
                ? nil
                : modelContainer.map { container in
                    CloudKitSyncMonitor(
                        syncStatusService: syncStatusService,
                        conflictHandler: conflictHandler,
                        integrityValidator: SyncIntegrityValidator(modelContainer: container)
                    )
                }
        )
        _appState = State(
            initialValue: AppState(
                isAuthenticated: isUITesting,
                isLocked: false,
                isOnboardingComplete: Self.initialOnboardingCompletionState(
                    showsOnboardingForUITesting: showsOnboardingForUITesting,
                    bypassOnboardingForUITesting: bypassOnboardingForUITesting
                ),
                isUITesting: isUITesting
            )
        )

        if let recurringRuleRepository = dependencyContainer.recurringRuleRepository,
           let transactionRepository = dependencyContainer.transactionRepository,
           let accountRepository = dependencyContainer.accountRepository {
            recurringGenerationUseCase = GenerateRecurringTransactionsUseCase(
                ruleRepository: recurringRuleRepository,
                transactionRepository: transactionRepository,
                accountRepository: accountRepository
            )
        } else {
            recurringGenerationUseCase = nil
        }

        #if os(iOS)
        if !isRunningAutomatedTests, let recurringGenerationUseCase {
            BackgroundTaskScheduler.register(generateUseCase: recurringGenerationUseCase)
        }
        #endif
    }

    private static func initialOnboardingCompletionState(
        showsOnboardingForUITesting: Bool,
        bypassOnboardingForUITesting: Bool
    ) -> Bool {
        if showsOnboardingForUITesting {
            KeychainService.syncDelete(forKey: "vittora.onboardingComplete")
            return false
        }

        if bypassOnboardingForUITesting { return true }

        // Keychain is authoritative; migrate from UserDefaults on first upgrade
        if let data = KeychainService.syncLoad(forKey: "vittora.onboardingComplete") {
            return data.first == 1
        }
        let udValue = UserDefaults.standard.bool(forKey: "vittora.onboardingComplete")
        if udValue {
            KeychainService.syncSave(Data([1]), forKey: "vittora.onboardingComplete")
            UserDefaults.standard.removeObject(forKey: "vittora.onboardingComplete")
        }
        return udValue
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .environment(appState)
                    .environment(router)
                    .environment(\.dependencies, dependencies)
                    .environment(settingsVM)
                    .environment(syncService)
                    .environment(syncConflictHandler)
                    .environment(\.currencyCode, settingsVM.selectedCurrencyCode)
                    .environment(\.currencySymbol, String.currencySymbol(for: settingsVM.selectedCurrencyCode))
                    .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
                    .modelContainer(modelContainer)
                    .overlay(alignment: .top) {
                        if let startupErrorMessage {
                            StartupRecoveryBanner(message: startupErrorMessage)
                                .padding(.horizontal, VSpacing.screenPadding)
                                .padding(.top, VSpacing.sm)
                        }
                    }
                    .task {
                        await performStartupTasksIfNeeded()
                    }
            } else {
                StartupFailureView(
                    message: startupFailureMessage
                        ?? String(localized: "Vittora couldn't open its data store or create a recovery store.")
                )
                .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            let shouldShowPrivacyShield = newPhase == .inactive || newPhase == .background
            appState.isPrivacyShieldVisible = !isRunningAutomatedTests && shouldShowPrivacyShield

            if newPhase == .background && !isRunningAutomatedTests && settingsVM.isAppLockEnabled {
                appState.isLocked = true
                appState.isAuthenticated = false
            }
            if newPhase == .active {
                appState.isPrivacyShieldVisible = false
                PerformanceLogger.App.sceneDidBecomeActive()
                guard !isRunningAutomatedTests else { return }
                Task {
                    await syncService.checkiCloudStatus()
                    #if os(iOS)
                    BackgroundTaskScheduler.scheduleNextRefresh()
                    #endif
                }
            }
        }
    }

    private func performStartupTasksIfNeeded() async {
        guard !hasCompletedStartup else { return }
        hasCompletedStartup = true

        if seedsTransfersForUITesting {
            await seedUITestTransferScenarioIfNeeded()
            return
        }

        if seedsTransactionsForUITesting {
            await seedUITestTransactionsIfNeeded()
            return
        }

        guard !isRunningAutomatedTests else { return }

        guard let modelContainer else { return }
        let dataSeeder = DefaultDataSeeder(modelContainer: modelContainer)
        do {
            try await dataSeeder.seedDefaultCategoriesIfNeeded()
        } catch {
            Self.logger.error("Failed to seed default categories: \(error.localizedDescription, privacy: .public)")
        }

        guard let recurringGenerationUseCase else { return }
        do {
            _ = try await recurringGenerationUseCase.execute()
        } catch {
            Self.logger.error("Failed to generate recurring transactions on launch: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func seedUITestTransactionsIfNeeded() async {
        guard let accountRepository = dependencies.accountRepository,
              let categoryRepository = dependencies.categoryRepository,
              let transactionRepository = dependencies.transactionRepository else {
            return
        }

        let seeder = UITestDataSeeder(
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            transactionRepository: transactionRepository
        )

        do {
            try await seeder.seedTransactionScenarioIfNeeded()
        } catch {
            Self.logger.error("Failed to seed UI test transaction data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func seedUITestTransferScenarioIfNeeded() async {
        guard let accountRepository = dependencies.accountRepository,
              let categoryRepository = dependencies.categoryRepository,
              let transactionRepository = dependencies.transactionRepository else {
            return
        }

        let seeder = UITestDataSeeder(
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            transactionRepository: transactionRepository
        )

        do {
            try await seeder.seedTransferScenarioIfNeeded()
        } catch {
            Self.logger.error("Failed to seed UI test transfer data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeStartupModelContainer(
        inMemory: Bool
    ) -> (container: ModelContainer?, errorMessage: String?, failureMessage: String?) {
        do {
            return (try ModelContainerConfig.makeContainer(inMemory: inMemory), nil, nil)
        } catch {
            logger.error("Failed to create persistent ModelContainer: \(error.localizedDescription, privacy: .public)")

            do {
                let recoveryContainer = try ModelContainerConfig.makeContainer(inMemory: true)
                let message = String(localized: "Vittora couldn't open its data store, so it started in recovery mode. Your saved data was left untouched.")
                return (recoveryContainer, message, nil)
            } catch {
                logger.fault("Failed to create recovery ModelContainer: \(error.localizedDescription, privacy: .public)")
                let message = String(localized: "Vittora couldn't open its data store or create a recovery store. Please restart the app and contact support if this continues.")
                return (nil, nil, message)
            }
        }
    }
}

private struct StartupRecoveryBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VColors.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(String(localized: "Recovery Mode"))
                    .font(VTypography.caption1Bold)
                    .foregroundStyle(VColors.textPrimary)
                Text(message)
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColors.warning.opacity(0.14))
        .overlay {
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                .stroke(VColors.warning.opacity(0.35), lineWidth: 1)
        }
        .cornerRadius(VSpacing.cornerRadiusMD)
        .accessibilityElement(children: .combine)
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "Vittora Couldn't Start"), systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        }
        .background(VColors.background)
    }
}
