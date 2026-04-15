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
    private let recurringGenerationUseCase: GenerateRecurringTransactionsUseCase?

    init() {
        isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        do {
            modelContainer = try ModelContainerConfig.makeContainer(inMemory: isUITesting)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let dependencyContainer = DependencyContainer.createDefault(modelContainer: modelContainer)
        let syncStatusService = SyncStatusService(isMonitoringEnabled: !isUITesting)
        let conflictHandler = SyncConflictHandler()
        _dependencies = State(initialValue: dependencyContainer)
        _router = State(initialValue: Router())
        _settingsVM = State(initialValue: SettingsViewModel())
        _syncService = State(initialValue: syncStatusService)
        _syncConflictHandler = State(initialValue: conflictHandler)
        _cloudKitSyncMonitor = State(
            initialValue: isUITesting
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
                isOnboardingComplete: isUITesting || UserDefaults.standard.bool(forKey: "vittora.onboardingComplete"),
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
        if !isUITesting, let recurringGenerationUseCase {
            BackgroundTaskScheduler.register(generateUseCase: recurringGenerationUseCase)
        }
        #endif
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
            if newPhase == .background && !isUITesting && settingsVM.isAppLockEnabled {
                appState.isLocked = true
                appState.isAuthenticated = false
            }
            if newPhase == .active {
                PerformanceLogger.App.sceneDidBecomeActive()
                guard !isUITesting else { return }
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
        guard !isUITesting else { return }

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
}
