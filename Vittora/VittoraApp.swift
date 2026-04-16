//
//  VittoraApp.swift
//  Vittora
//
//  Created by Rahul on 12/04/26.
//

import SwiftUI
import SwiftData

@main
struct VittoraApp: App {
    @State private var appState: AppState
    @State private var router: Router
    @State private var dependencies: DependencyContainer
    @State private var settingsVM: SettingsViewModel
    @State private var syncService: SyncStatusService
    @State private var syncConflictHandler: SyncConflictHandler
    @State private var cloudKitSyncMonitor: CloudKitSyncMonitor?
    @State private var hasCompletedStartup = false
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let isUITesting: Bool
    private let isRunningAutomatedTests: Bool
    private let showsOnboardingForUITesting: Bool
    private let bypassOnboardingForUITesting: Bool
    private let seedsTransactionsForUITesting: Bool
    private let seedsTransfersForUITesting: Bool
    private let recurringGenerationUseCase: GenerateRecurringTransactionsUseCase?

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        isUITesting = launchArguments.contains("--uitesting")
        isRunningAutomatedTests = isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        showsOnboardingForUITesting = launchArguments.contains("--ui-test-onboarding")
        bypassOnboardingForUITesting = isUITesting && !showsOnboardingForUITesting
        seedsTransactionsForUITesting = launchArguments.contains("--ui-test-seed-transactions")
        seedsTransfersForUITesting = launchArguments.contains("--ui-test-seed-transfers")

        do {
            modelContainer = try ModelContainerConfig.makeContainer(inMemory: isRunningAutomatedTests)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let dependencyContainer = DependencyContainer.createDefault(modelContainer: modelContainer)
        let syncStatusService = SyncStatusService(isMonitoringEnabled: !isRunningAutomatedTests)
        let conflictHandler = SyncConflictHandler()
        _dependencies = State(initialValue: dependencyContainer)
        _router = State(initialValue: Router())
        _settingsVM = State(initialValue: SettingsViewModel())
        _syncService = State(initialValue: syncStatusService)
        _syncConflictHandler = State(initialValue: conflictHandler)
        _cloudKitSyncMonitor = State(
            initialValue: isRunningAutomatedTests
                ? nil
                : CloudKitSyncMonitor(
                    syncStatusService: syncStatusService,
                    conflictHandler: conflictHandler
                )
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
            UserDefaults.standard.removeObject(forKey: "vittora.onboardingComplete")
            return false
        }

        if bypassOnboardingForUITesting {
            return true
        }

        return UserDefaults.standard.bool(forKey: "vittora.onboardingComplete")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(router)
                .environment(\.dependencies, dependencies)
                .environment(settingsVM)
                .environment(syncService)
                .environment(syncConflictHandler)
                .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
                .task {
                    await performStartupTasksIfNeeded()
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && !isRunningAutomatedTests && settingsVM.isAppLockEnabled {
                appState.isLocked = true
                appState.isAuthenticated = false
            }
            if newPhase == .active {
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

        let dataSeeder = DefaultDataSeeder(modelContainer: modelContainer)
        do {
            try await dataSeeder.seedDefaultCategoriesIfNeeded()
        } catch {
            debugPrint("Failed to seed default categories: \(error)")
        }

        guard let recurringGenerationUseCase else { return }
        do {
            _ = try await recurringGenerationUseCase.execute()
        } catch {
            debugPrint("Failed to generate recurring transactions on launch: \(error)")
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
            debugPrint("Failed to seed UI test transaction data: \(error)")
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
            debugPrint("Failed to seed UI test transfer data: \(error)")
        }
    }
}
