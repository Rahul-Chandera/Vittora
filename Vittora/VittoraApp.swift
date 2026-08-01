//
//  VittoraApp.swift
//  Vittora
//
//  Created by Rahul on 12/04/26.
//

import SwiftUI
import SwiftData
import OSLog
import CoreSpotlight
import VittoraCore
#if os(iOS)
import UIKit
#endif

@main
struct VittoraApp: App {
    private static let logger = Logger(subsystem: "com.vittora.app", category: "startup")

    @State private var appState: AppState
    @State private var dependencies: DependencyContainer
    @State private var settingsVM: SettingsViewModel
    @State private var syncService: SyncStatusService
    @State private var syncConflictHandler: SyncConflictHandler
    @State private var cloudKitSyncMonitor: CloudKitSyncMonitor?
    #if os(iOS)
    @State private var watchBridge: WatchBridgeService?
    #endif
    @State private var notificationTimeChangeObservers: [NSObjectProtocol] = []
    @State private var spotlightCoordinator: TransactionSpotlightCoordinator?
    @State private var hasCompletedStartup = false
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer?
    private let isUITesting: Bool
    private let isRunningAutomatedTests: Bool
    private let showsOnboardingForUITesting: Bool
    private let bypassOnboardingForUITesting: Bool
    private let seedsTransactionsForUITesting: Bool
    private let seedsTransfersForUITesting: Bool
    private let seedsDemoShowcaseForUITesting: Bool
    private let exercisesAppLockPolicy: Bool
    private let startupErrorMessage: String?
    private let startupFailureMessage: String?
    private let recurringGenerationCoordinator: RecurringGenerationCoordinator?

    init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        isUITesting = launchArguments.contains("--uitesting")
        isRunningAutomatedTests = isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        showsOnboardingForUITesting = launchArguments.contains("--ui-test-onboarding")
            || ProcessInfo.processInfo.environment["UITEST_FORCE_ONBOARDING"] == "1"
        bypassOnboardingForUITesting = isUITesting && !showsOnboardingForUITesting
        seedsTransactionsForUITesting = launchArguments.contains("--ui-test-seed-transactions")
        seedsTransfersForUITesting = launchArguments.contains("--ui-test-seed-transfers")
        seedsDemoShowcaseForUITesting = launchArguments.contains("--ui-test-seed-demo")
        exercisesAppLockPolicy = launchArguments.contains("--ui-test-app-lock")

        if isUITesting {
            Self.configureAppearanceForUITesting(arguments: launchArguments)
        }

        if launchArguments.contains("--ui-test-seed-demo") {
            // The currency environment is captured from Settings at first
            // render, before async seeding runs — set it up front so demo
            // screenshots show the right symbol.
            let region = ProcessInfo.processInfo.environment["UITEST_DEMO_REGION"] ?? "US"
            UserDefaults.standard.set(
                region == "IN" ? "INR" : "USD",
                forKey: AppUserDefaults.StandardKey.currencyCode
            )
        }

        // Keep the App Group currency mirror current for widget extensions.
        AppUserDefaults.mirrorCurrencyCodeToAppGroup()
        AppUserDefaults.mirrorAccentColorToAppGroup()

        // Keychain + App Group App Lock state survives relaunch; UI tests must
        // declare unlocked vs locked rather than inheriting the previous case.
        if launchArguments.contains("--ui-test-reset-app-lock") {
            Self.resetAppLockUITestState()
        }

        if exercisesAppLockPolicy {
            KeychainService.syncSave(Data([1]), forKey: AppUserDefaults.KeychainKey.appLockEnabled)
            UserDefaults.standard.set(
                AppLockTimeout.immediately.rawValue,
                forKey: AppUserDefaults.StandardKey.appLockTimeout
            )
        }

        let startupContainer = Self.makeStartupModelContainer(inMemory: isRunningAutomatedTests)
        modelContainer = startupContainer.container
        startupErrorMessage = startupContainer.errorMessage
        startupFailureMessage = startupContainer.failureMessage

        let dependencyContainer: DependencyContainer
        if let modelContainer {
            dependencyContainer = DependencyContainer.createDefault(modelContainer: modelContainer)
        } else {
            dependencyContainer = DependencyContainer.startupFailure()
        }
        let syncStatusService = SyncStatusService(isMonitoringEnabled: !isRunningAutomatedTests)
        let conflictHandler = SyncConflictHandler(
            auditLogger: dependencyContainer.securityAuditLogService
        )
        _dependencies = State(initialValue: dependencyContainer)
        let keychainService = dependencyContainer.keychainService
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
        let spotlight: TransactionSpotlightCoordinator? = isRunningAutomatedTests
            ? nil
            : TransactionSpotlightCoordinator(
                transactionRepository: dependencyContainer.transactionRepository,
                payeeRepository: dependencyContainer.payeeRepository,
                categoryRepository: dependencyContainer.categoryRepository
            )
        _spotlightCoordinator = State(initialValue: spotlight)
        _appState = State(
            initialValue: AppState(
                isAuthenticated: isUITesting,
                isLocked: false,
                isOnboardingComplete: Self.initialOnboardingCompletionState(
                    showsOnboardingForUITesting: showsOnboardingForUITesting,
                    bypassOnboardingForUITesting: bypassOnboardingForUITesting
                ),
                selectedTab: Self.initialSelectedTab(isUITesting: isUITesting),
                isUITesting: isUITesting,
                exercisesAppLockPolicy: exercisesAppLockPolicy,
                isRecoveryMode: startupErrorMessage != nil
            )
        )

        recurringGenerationCoordinator = dependencyContainer.recurringGenerationCoordinator

        #if os(iOS)
        if !isRunningAutomatedTests, let recurringGenerationCoordinator {
            BackgroundTaskScheduler.register(coordinator: recurringGenerationCoordinator)
        }
        #endif
    }

    /// Clears persisted App Lock intent + policy mirrors for UI-test isolation.
    private static func resetAppLockUITestState() {
        KeychainService.syncDelete(forKey: AppUserDefaults.KeychainKey.appLockEnabled)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockEnabledLegacy)
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockTimeout)
        AppLockSessionMirror.clearAll()
    }

    private static func configureAppearanceForUITesting(arguments: [String]) {
        let appearancePrefix = "--ui-test-appearance="
        let accentPrefix = "--ui-test-accent="
        let appearance = arguments.first { $0.hasPrefix(appearancePrefix) }
            .map { String($0.dropFirst(appearancePrefix.count)) }
        let accent = arguments.first { $0.hasPrefix(accentPrefix) }
            .map { String($0.dropFirst(accentPrefix.count)) }

        if let appearance, appearanceModeRawValues.contains(appearance) {
            UserDefaults.standard.set(appearance, forKey: AppUserDefaults.StandardKey.appearanceMode)
        } else {
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appearanceMode)
        }

        if let accent, accentColorRawValues.contains(accent) {
            UserDefaults.standard.set(accent, forKey: AppUserDefaults.StandardKey.accentColor)
        } else {
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.accentColor)
        }

        // These wrote the defaults behind the observable mirror's back.
        ThemeState.shared.reloadFromDefaults()
    }

    private static let appearanceModeRawValues = Set(["system", "light", "dark", "oledBlack"])
    private static let accentColorRawValues = Set(["brandGreen", "blue", "purple", "orange"])

    private static func initialOnboardingCompletionState(
        showsOnboardingForUITesting: Bool,
        bypassOnboardingForUITesting: Bool
    ) -> Bool {
        if showsOnboardingForUITesting {
            KeychainService.syncDelete(forKey: AppUserDefaults.KeychainKey.onboardingComplete)
            KeychainService.syncDelete(forKey: AppUserDefaults.KeychainKey.appLockEnabled)
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.KeychainKey.onboardingComplete)
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockTimeout)
            return false
        }

        if bypassOnboardingForUITesting { return true }

        // Keychain is authoritative; migrate from UserDefaults on first upgrade
        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.onboardingComplete) {
            return data.first == 1
        }
        let udValue = UserDefaults.standard.bool(forKey: AppUserDefaults.KeychainKey.onboardingComplete)
        if udValue {
            KeychainService.syncSave(Data([1]), forKey: AppUserDefaults.KeychainKey.onboardingComplete)
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.KeychainKey.onboardingComplete)
        }
        return udValue
    }

    private static func initialSelectedTab(isUITesting: Bool) -> AppState.AppTab {
        guard isUITesting,
              let rawValue = ProcessInfo.processInfo.environment["UITEST_INITIAL_TAB"],
              let tab = AppState.AppTab(rawValue: rawValue) else {
            return .dashboard
        }
        return tab
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                // The banner lives ABOVE the content in a VStack — an overlay
                // (or safeAreaInset, which NavigationSplitView columns ignore)
                // floats over the sidebar and screen titles.
                VStack(spacing: 0) {
                    if let startupErrorMessage {
                        StartupRecoveryBanner(message: startupErrorMessage)
                            .padding(.horizontal, VSpacing.screenPadding)
                            .padding(.vertical, VSpacing.sm)
                    }

                    ContentView()
                }
                    .vittoraAppEnvironments(
                        appState: appState,
                        dependencies: dependencies,
                        settingsVM: settingsVM,
                        syncService: syncService,
                        syncConflictHandler: syncConflictHandler,
                        modelContainer: modelContainer
                    )
                    .restoresSceneState(appState: appState)
                    .background(VColors.background.ignoresSafeArea())
                    #if os(macOS)
                    .frame(minWidth: 960, minHeight: 640)
                    #endif
                    .task {
                        registerQuickAddIntentHandler()
                        #if os(iOS)
                        activateWatchBridgeIfNeeded()
                        #endif
                        registerSpotlightSyncHook()
                        await performStartupTasksIfNeeded()
                        #if os(iOS)
                        // Seed (and other startup writes) finish after activate; push once more
                        // so the watch gets a post-seed snapshot without waiting for a later edit.
                        watchBridge?.pushSnapshot()
                        #endif
                        openUITestURLIfNeeded()
                        await showSpendingIntentResultIfNeeded()
                    }
                    .onOpenURL { url in
                        appState.openFromURL(url)
                    }
                    .onContinueUserActivity(CSSearchableItemActionType) { activity in
                        if let id = TransactionSpotlightIndex.transactionID(fromUserActivity: activity) {
                            appState.openFromSpotlight(transactionID: id)
                        }
                    }
                    .alert(
                        String(localized: "Today's Spending"),
                        isPresented: Binding(
                            get: { appState.uiTestIntentResultMessage != nil },
                            set: { if !$0 { appState.uiTestIntentResultMessage = nil } }
                        )
                    ) {
                        Button(String(localized: "OK"), role: .cancel) {
                            appState.uiTestIntentResultMessage = nil
                        }
                    } message: {
                        Text(appState.uiTestIntentResultMessage ?? "")
                    }
            } else {
                StartupFailureView(
                    message: startupFailureMessage
                        ?? String(localized: "Vittora couldn't open its data store or create a recovery store.")
                )
                .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
                .tint(VColors.accent(settingsVM.accentColor))
            }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button(String(localized: "New Transaction")) {
                    appState.request(.presentNewTransaction)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(String(localized: "Go to")) {
                ForEach(Array(AppState.AppTab.allCases.enumerated()), id: \.offset) { index, tab in
                    Button(tab.title) {
                        appState.request(.selectTab(tab))
                    }
                    .keyboardShortcut(
                        tabShortcutKey(at: index),
                        modifiers: .command
                    )
                }
            }
        }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            let shouldShowPrivacyShield = newPhase == .inactive || newPhase == .background
            appState.isPrivacyShieldVisible = !isRunningAutomatedTests && shouldShowPrivacyShield

            guard !isRunningAutomatedTests || exercisesAppLockPolicy else {
                if newPhase == .active {
                    appState.isPrivacyShieldVisible = false
                }
                return
            }

            switch newPhase {
            case .inactive:
                // UI-test harness: home press often stops at .inactive on Simulator.
                if exercisesAppLockPolicy, settingsVM.isAppLockEnabled {
                    recordAppLockBackgrounded()
                }
            case .background:
                if settingsVM.isAppLockEnabled {
                    recordAppLockBackgrounded()
                }
            case .active:
                applyAppLockPolicyOnBecomeActive()
                appState.isPrivacyShieldVisible = false
                PerformanceLogger.App.sceneDidBecomeActive()
                Task {
                    await syncService.checkiCloudStatus()
                    #if os(iOS)
                    BackgroundTaskScheduler.scheduleNextRefresh()
                    watchBridge?.pushSnapshot()
                    #endif
                }
            default:
                break
            }
        }
        .onChange(of: syncService.iCloudAccountAvailable) { _, available in
            appState.isHandoffAdvertisingSuspended = !available
        }

        #if os(macOS)
        Settings {
            if let modelContainer {
                SettingsView()
                    .vittoraAppEnvironments(
                        appState: appState,
                        dependencies: dependencies,
                        settingsVM: settingsVM,
                        syncService: syncService,
                        syncConflictHandler: syncConflictHandler,
                        modelContainer: modelContainer
                    )
                    .frame(minWidth: 520, minHeight: 480)
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Settings Unavailable"), systemImage: "gearshape")
                } description: {
                    Text(String(localized: "Vittora could not open its data store."))
                }
            }
        }
        #endif
    }

    private func tabShortcutKey(at index: Int) -> KeyEquivalent {
        guard let scalar = UnicodeScalar(49 + index) else {
            return KeyEquivalent(Character("1"))
        }
        return KeyEquivalent(Character(scalar))
    }

    /// Persists background stamp + timeout into the App Group so Siri/intents
    /// apply the same `AppLockPolicy.shouldLock` rule as become-active.
    private func recordAppLockBackgrounded(at date: Date = .now) {
        dependencies.appLockService.recordBackgrounded(at: date)
        AppLockSessionMirror.mirrorBackgrounded(
            at: date,
            timeout: settingsVM.appLockTimeout.timeInterval
        )
    }

    /// Re-lock only when background duration meets the configured timeout (B1).
    private func applyAppLockPolicyOnBecomeActive() {
        guard settingsVM.isAppLockEnabled else {
            appState.isLocked = false
            return
        }

        let service = dependencies.appLockService
        if let backgroundedAt = service.lastBackgroundedAt,
           AppLockPolicy.shouldLock(
               backgroundedAt: backgroundedAt,
               now: .now,
               timeout: settingsVM.appLockTimeout.timeInterval
           ) {
            appState.isLocked = true
            appState.isAuthenticated = false
            Task { await service.lock() }
        } else if !appState.isAuthenticated {
            appState.isLocked = true
        }
    }

    private func configureNotificationService() async {
        dependencies.notificationService.setDeepLinkHandler { [appState] deepLink in
            appState.openFromNotification(deepLink)
        }
        await dependencies.notificationService.registerCategories()
        registerNotificationTimeChangeObservers()
        await scheduleVerificationNotificationIfNeeded()
    }

    private func registerNotificationTimeChangeObservers() {
        guard notificationTimeChangeObservers.isEmpty else { return }
        var names = [Notification.Name.NSSystemTimeZoneDidChange]
        #if os(iOS)
        names.append(UIApplication.significantTimeChangeNotification)
        #endif
        notificationTimeChangeObservers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    refreshNotificationSchedulesAfterTimeChange()
                }
            }
        }
    }

    private func refreshNotificationSchedulesAfterTimeChange() {
        guard !isRunningAutomatedTests, settingsVM.isNotificationsEnabled else { return }
        Task {
            await dependencies.notificationService.reschedulePending()
            await dependencies.refreshAllNotificationSchedules()
        }
    }

    private func scheduleVerificationNotificationIfNeeded() async {
        let prefix = "--verify-notification-delay="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
              let delay = TimeInterval(argument.dropFirst(prefix.count)),
              delay >= 2,
              (try? await dependencies.notificationService.requestAuthorization()) == true
        else {
            return
        }
        try? await dependencies.notificationService.schedule(
            ScheduledNotificationRequest(
                identifier: "notification-schedule-verification",
                title: String(localized: "Vittora Notification"),
                body: String(localized: "Scheduled delivery verified."),
                fireDate: .now.addingTimeInterval(delay),
                category: .budgetAlert,
                deepLink: VittoraNotificationDeepLink(destination: .budgets)
            )
        )
    }

    /// W5: AddExpenseIntent → same `openFromURL` path as widget / `vittora://add` links.
    private func registerQuickAddIntentHandler() {
        QuickAddDeepLink.registerOpenHandler { [appState] destination in
            appState.openFromURL(QuickAddDeepLink.url(for: destination))
        }
    }

    #if os(iOS)
    private func activateWatchBridgeIfNeeded() {
        guard watchBridge == nil, let modelContainer else { return }

        let provider = WidgetDataProvider(container: modelContainer)
        let transactionRepository = dependencies.transactionRepository
        let accountRepository = dependencies.accountRepository
        let categoryRepository = dependencies.categoryRepository
        let ledgerWriting = dependencies.ledgerWriteStore
        let addUseCase = AddTransactionUseCase(
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            ledgerWriting: ledgerWriting
        )

        let bridge = WatchBridgeService(
            buildSnapshot: {
                try await WatchSnapshotBuilder.build(
                    provider: provider,
                    transactionRepository: transactionRepository,
                    categoryRepository: categoryRepository
                )
            },
            commitExpense: { expense in
                let accounts = try await accountRepository.fetchActive()
                guard let account = accounts.first else {
                    throw VittoraError.validationFailed(
                        String(localized: "No account available for Watch expenses.")
                    )
                }
                _ = try await addUseCase.execute(
                    amount: expense.amount,
                    type: .expense,
                    date: expense.createdAt,
                    categoryID: expense.categoryID,
                    accountID: account.id,
                    payeeID: nil,
                    note: String(localized: "Apple Watch"),
                    tags: [],
                    paymentMethod: .other,
                    currencyCode: CurrencyDefaults.code
                )
            },
            presentError: { [appState] message in
                appState.watchBridgeErrorMessage = message
            },
            notifyCommitted: { [appState] in
                appState.notifyChanged([.transactions, .accounts, .budgets])
            }
        )
        watchBridge = bridge
        appState.watchBridge = bridge
        bridge.activate()
        bridge.pushSnapshot()
        commitVerificationWatchExpenseIfNeeded(using: bridge)
    }

    /// WA1 verification only — injects a queued-expense payload through the same
    /// `handleIncomingUserInfo` path WCSession uses, so screenshots don't depend
    /// on flaky Simulator `transferUserInfo` delivery.
    private func commitVerificationWatchExpenseIfNeeded(using bridge: WatchBridgeService) {
        let prefix = "--verify-commit-watch-expense="
        guard let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return
        }
        let amountRaw = String(raw.dropFirst(prefix.count))
        guard let amount = Decimal(string: amountRaw), amount > 0 else { return }
        let payload = QueuedWatchExpense(amount: amount, categoryID: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            await bridge.handleIncomingUserInfo(payload.userInfoDictionary())
        }
    }
    #endif

    /// P2: keep Spotlight in sync with transaction mutations (batch, background).
    private func registerSpotlightSyncHook() {
        guard let spotlightCoordinator else { return }
        appState.onTransactionsChangedForSpotlight = { [spotlightCoordinator] in
            spotlightCoordinator.scheduleSync()
        }
        // First launch after Spotlight update does a full domain replace.
        spotlightCoordinator.scheduleSync(forceFullReindex: TransactionSpotlightIndex.needsFullReindex())
    }

    private func openUITestURLIfNeeded() {
        let quickAddPrefix = "--ui-test-quick-add="
        if let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(quickAddPrefix) }) {
            let type = String(raw.dropFirst(quickAddPrefix.count)).lowercased()
            if let destination = QuickAddDeepLink.Destination(rawValue: type) {
                // Defer until navigation shells have attached command handlers.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    appState.openFromURL(QuickAddDeepLink.url(for: destination))
                }
            }
        }

        let transactionPrefix = "--ui-test-open-transaction="
        if let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(transactionPrefix) }) {
            let idString = String(raw.dropFirst(transactionPrefix.count))
            if let id = UUID(uuidString: idString) {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    appState.openFromURL(TransactionSpotlightDeepLink.url(for: id))
                }
            }
        }

        // Any `vittora://` route, applied in-process at launch. `simctl openurl`
        // reaches the same routing, but SpringBoard puts an "Open in …?" alert on
        // screen first, which is fatal for store screenshots.
        let urlPrefix = "--ui-test-open-url="
        if let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(urlPrefix) }),
           let url = URL(string: String(raw.dropFirst(urlPrefix.count))) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                appState.openFromURL(url)
            }
        }
    }

    /// Runs `TodaySpendingQuery` (same path as GetTodaySpendingIntent) for screenshot verification.
    private func showSpendingIntentResultIfNeeded() async {
        guard ProcessInfo.processInfo.arguments.contains("--ui-test-show-spending-intent-result") else {
            return
        }
        // Mirror locked session when exercising App Lock so the gate matches Shortcuts.
        if exercisesAppLockPolicy {
            AppLockSessionMirror.mirrorFromAppState(
                isAppLockEnabled: true,
                isLocked: true,
                isAuthenticated: false,
                timeout: AppLockTimeout.immediately.timeInterval
            )
        }
        // UI tests use an in-memory host store; the App Group on-disk store may be
        // absent. Prefer the test container so unlocked queries still return a summary.
        let message: String
        if isUITesting, let modelContainer {
            message = await TodaySpendingQuery.run(
                provider: WidgetDataProvider(container: modelContainer)
            )
        } else {
            message = await TodaySpendingQuery.run()
        }
        appState.uiTestIntentResultMessage = message
    }

    private func performStartupTasksIfNeeded() async {
        guard !hasCompletedStartup else { return }
        hasCompletedStartup = true

        if seedsDemoShowcaseForUITesting {
            await seedUITestDemoShowcaseIfNeeded()
            return
        }

        if seedsTransfersForUITesting {
            await seedUITestTransferScenarioIfNeeded()
            return
        }

        if seedsTransactionsForUITesting {
            await seedUITestTransactionsIfNeeded()
            return
        }

        guard !isRunningAutomatedTests else { return }

        await configureNotificationService()
        await dependencies.refreshCreditCardDueReminders()

        guard modelContainer != nil else { return }
        do {
            try await dependencies.dataSeeder.seedDefaultCategoriesIfNeeded()
        } catch {
            Self.logger.error("Failed to seed default categories: \(error.localizedDescription, privacy: .public)")
        }

        do {
            _ = try await dependencies.recurringGenerationCoordinator.generate()
        } catch {
            Self.logger.error("Failed to generate recurring transactions on launch: \(error.localizedDescription, privacy: .public)")
        }
        await dependencies.refreshRecurringAndDebtReminders()
    }

    private func seedUITestTransactionsIfNeeded() async {
        let seeder = UITestDataSeeder(
            accountRepository: dependencies.accountRepository,
            categoryRepository: dependencies.categoryRepository,
            transactionRepository: dependencies.transactionRepository,
            ledgerWriting: dependencies.ledgerWriteStore
        )

        do {
            try await seeder.seedTransactionScenarioIfNeeded(
                payeeRepository: dependencies.payeeRepository,
                recurringRuleRepository: dependencies.recurringRuleRepository
            )
            appState.notifyChanged([.transactions, .accounts, .categories, .recurring, .payees])
        } catch {
            Self.logger.error("Failed to seed UI test transaction data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func seedUITestDemoShowcaseIfNeeded() async {
        let seeder = UITestDataSeeder(
            accountRepository: dependencies.accountRepository,
            categoryRepository: dependencies.categoryRepository,
            transactionRepository: dependencies.transactionRepository,
            ledgerWriting: dependencies.ledgerWriteStore
        )

        do {
            try await seeder.seedDemoShowcaseIfNeeded(
                budgetRepository: dependencies.budgetRepository,
                savingsGoalRepository: dependencies.savingsGoalRepository,
                debtRepository: dependencies.debtRepository,
                recurringRuleRepository: dependencies.recurringRuleRepository,
                payeeRepository: dependencies.payeeRepository,
                splitGroupRepository: dependencies.splitGroupRepository,
                taxProfileRepository: dependencies.taxProfileRepository,
                dataSeeder: dependencies.dataSeeder
            )
            appState.notifyChanged([
                .transactions, .accounts, .categories, .budgets,
                .savings, .debt, .recurring, .payees, .splits
            ])
        } catch {
            Self.logger.error("Failed to seed demo showcase data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func seedUITestTransferScenarioIfNeeded() async {
        let seeder = UITestDataSeeder(
            accountRepository: dependencies.accountRepository,
            categoryRepository: dependencies.categoryRepository,
            transactionRepository: dependencies.transactionRepository,
            ledgerWriting: dependencies.ledgerWriteStore
        )

        do {
            try await seeder.seedTransferScenarioIfNeeded()
            appState.notifyChanged(.accounts)
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

    // The banner must carry its own escape hatch: recovery mode can coincide
    // with incomplete onboarding, where Settings → Delete All Data is
    // unreachable and the unopenable store would otherwise persist forever.
    @Environment(\.dependencies) private var dependencies
    @State private var showEraseConfirm = false
    @State private var showRestartPrompt = false
    @State private var isErasing = false
    @State private var eraseError: String?

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
                if let eraseError {
                    Text(eraseError)
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.expense)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: VSpacing.sm)

            Button(String(localized: "Erase & Start Fresh…")) {
                showEraseConfirm = true
            }
            .font(VTypography.caption1Bold)
            .disabled(isErasing)
        }
        .padding(VSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VColors.warning.opacity(0.14))
        .overlay {
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                .stroke(VColors.warning.opacity(0.35), lineWidth: 1)
        }
        .cornerRadius(VSpacing.cornerRadiusMD)
        .confirmationDialog(
            String(localized: "Erase the unopenable data store?"),
            isPresented: $showEraseConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Erase Everything"), role: .destructive) {
                Task { await eraseAndStartFresh() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This permanently deletes the data store Vittora couldn't open, along with saved settings. This cannot be undone."))
        }
        .alert(
            String(localized: "Data Erased"),
            isPresented: $showRestartPrompt
        ) {
            #if os(macOS)
            Button(String(localized: "Quit Vittora")) {
                NSApp.terminate(nil)
            }
            #endif
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Quit and reopen Vittora to finish leaving recovery mode with a fresh data store."))
        }
    }

    private func eraseAndStartFresh() async {
        isErasing = true
        eraseError = nil
        defer { isErasing = false }

        do {
            guard try await SensitiveActionAuthenticator.confirm(
                action: .factoryReset,
                using: dependencies.biometricService
            ) else {
                return
            }
            try await dependencies.makeDataManagementService()
                .factoryReset(alsoDestroyOnDiskStore: true)
            showRestartPrompt = true
        } catch {
            eraseError = error.localizedDescription
        }
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
