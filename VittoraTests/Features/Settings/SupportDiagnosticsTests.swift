import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Support diagnostics privacy", .serialized)
struct SupportDiagnosticsTests {

    @Test("demo dataset diagnostics omit amounts, notes, payees, account and category names")
    @MainActor
    func diagnosticPayloadOmitsSensitiveDemoFields() async throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let accountRepo = SwiftDataAccountRepository(modelContainer: container)
        let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepo = SwiftDataBudgetRepository(modelContainer: container)
        let savingsRepo = SwiftDataSavingsGoalRepository(modelContainer: container)
        let debtRepo = SwiftDataDebtRepository(modelContainer: container)
        let recurringRepo = SwiftDataRecurringRuleRepository(modelContainer: container)
        let payeeRepo = SwiftDataPayeeRepository(modelContainer: container)
        let splitGroupRepo = SwiftDataSplitGroupRepository(modelContainer: container)
        let taxProfileRepo = SwiftDataTaxProfileRepository(modelContainer: container)
        let ledger = LedgerWriteStore(modelContainer: container)
        let seeder = DefaultDataSeeder(modelContainer: container)

        let demo = UITestDataSeeder(
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            transactionRepository: transactionRepo,
            ledgerWriting: ledger
        )
        try await demo.seedDemoShowcaseIfNeeded(
            budgetRepository: budgetRepo,
            savingsGoalRepository: savingsRepo,
            debtRepository: debtRepo,
            recurringRuleRepository: recurringRepo,
            payeeRepository: payeeRepo,
            splitGroupRepository: splitGroupRepo,
            taxProfileRepository: taxProfileRepo,
            dataSeeder: seeder
        )

        let accounts = try await accountRepo.fetchAll()
        let categories = try await categoryRepo.fetchAll()
        let payees = try await payeeRepo.fetchAll()
        let transactions = try await transactionRepo.fetchAll(filter: nil)
        #expect(!accounts.isEmpty)
        #expect(!transactions.isEmpty)

        let errorSuite = "SupportDiagnosticsTests.errors.\(UUID().uuidString)"
        let errorDefaults = UserDefaults(suiteName: errorSuite)!
        defer { errorDefaults.removePersistentDomain(forName: errorSuite) }
        let errorLog = RecentErrorLogStore(defaults: errorDefaults)
        errorLog.record(errorType: "TestError", codePath: "SupportDiagnosticsTests.seed")

        let currencyKey = AppUserDefaults.StandardKey.currencyCode
        let previousCurrency = UserDefaults.standard.string(forKey: currencyKey)
        defer {
            if let previousCurrency {
                UserDefaults.standard.set(previousCurrency, forKey: currencyKey)
            } else {
                UserDefaults.standard.removeObject(forKey: currencyKey)
            }
        }

        let snapshot = DiagnosticSnapshot(
            appVersion: "1.0",
            buildNumber: "42",
            osName: "iOS",
            osVersion: "26.0",
            deviceModel: "iPhone17,1",
            localeIdentifier: "en_US",
            currencyCode: "USD",
            cloudSyncEnabled: false,
            lastSyncResult: "disabled",
            transactionCount: try await transactionRepo.fetchTransactionCount(),
            accountCount: accounts.count,
            categoryCount: categories.count,
            budgetCount: try await budgetRepo.fetchAll().count,
            debtCount: try await debtRepo.fetchAll().count,
            savingsGoalCount: try await savingsRepo.fetchAll().count,
            splitGroupCount: 0,
            documentCount: 0,
            payeeCount: payees.count,
            recurringRuleCount: try await recurringRepo.fetchAll().count,
            recentErrors: errorLog.recentEntries()
        )
        let payload = DiagnosticPayload.render(snapshot)

        // Amounts from the US demo dataset (and distinctive formatted forms).
        let forbiddenAmounts = [
            "15.49", "128.40", "96.20", "42.75", "142.10", "48.30", "89.65",
            "28.90", "132.80", "101.50", "36.40", "189.99", "118.25", "24.50",
            "54.20", "52.75", "27.35", "18.60", "6400", "1850", "4200",
        ]
        for amount in forbiddenAmounts {
            #expect(!payload.contains(amount), "payload must not contain amount \(amount)")
        }

        let forbiddenNotes = [
            "Weekly Groceries", "Dinner Delivery", "Groceries Restock", "Netflix",
            "Monthly Salary", "Monthly Rent", "Electric Bill", "Running Shoes",
            "Uber to Airport", "Weekend Brunch", "Movie Night", "Monthly Staples",
            "Pharmacy", "Lunch Order", "Concert tickets", "Gas",
        ]
        for note in forbiddenNotes {
            #expect(!payload.contains(note), "payload must not contain note \(note)")
        }

        for payee in payees {
            #expect(
                !containsWholeWord(payload, payee.name),
                "payload must not contain payee \(payee.name)"
            )
        }
        for account in accounts {
            #expect(
                !containsWholeWord(payload, account.name),
                "payload must not contain account \(account.name)"
            )
        }
        for category in categories {
            #expect(
                !containsWholeWord(payload, category.name),
                "payload must not contain category \(category.name)"
            )
        }

        #expect(payload.contains("Transactions: \(snapshot.transactionCount)"))
        #expect(payload.contains("Accounts: \(snapshot.accountCount)"))
        #expect(payload.contains(DiagnosticPayload.supportEmail) == false)
        #expect(payload.contains("support@vittora.app") == false)
    }

    @Test("diagnostic payload contains no persistent install or vendor identifier")
    func diagnosticPayloadOmitsPersistentIdentifiers() {
        let snapshot = DiagnosticSnapshot(
            appVersion: "1.0",
            buildNumber: "1",
            osName: "iOS",
            osVersion: "26.0",
            deviceModel: DiagnosticDeviceInfo.hardwareModel,
            localeIdentifier: "en_US",
            currencyCode: "USD",
            cloudSyncEnabled: true,
            lastSyncResult: "synced",
            transactionCount: 0,
            accountCount: 0,
            categoryCount: 0,
            budgetCount: 0,
            debtCount: 0,
            savingsGoalCount: 0,
            splitGroupCount: 0,
            documentCount: 0,
            payeeCount: 0,
            recurringRuleCount: 0,
            recentErrors: []
        )
        let payload = DiagnosticPayload.render(snapshot)
        #expect(!payload.localizedCaseInsensitiveContains("identifierForVendor"))
        #expect(!payload.localizedCaseInsensitiveContains("advertisingIdentifier"))
        #expect(!payload.localizedCaseInsensitiveContains("idfv"))
        #expect(!payload.localizedCaseInsensitiveContains("idfa"))
        #expect(!payload.contains("00000000-0000-0000-0000-000000000000"))
    }

    @Test("error log stores code path but never record contents")
    func errorLogStoresCodePathOnly() {
        let suite = "SupportDiagnosticsTests.log.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentErrorLogStore(defaults: defaults)
        store.record(errorType: "ValidationError", codePath: "AddTransactionUseCase.execute")

        // Attempt to sneak record contents into the type — store truncates but
        // callers must pass type/path only; assert the API surface has no content slot.
        let entries = store.recentEntries()
        #expect(entries.count == 1)
        #expect(entries[0].errorType == "ValidationError")
        #expect(entries[0].codePath == "AddTransactionUseCase.execute")
        #expect(!entries[0].codePath.contains("DoorDash"))
        #expect(!entries[0].errorType.contains("15.49"))

        let rendered = DiagnosticPayload.render(
            DiagnosticSnapshot(
                appVersion: "1.0",
                buildNumber: "1",
                osName: "iOS",
                osVersion: "26.0",
                deviceModel: "iPhone",
                localeIdentifier: "en_US",
                currencyCode: "USD",
                cloudSyncEnabled: false,
                lastSyncResult: "disabled",
                transactionCount: 0,
                accountCount: 0,
                categoryCount: 0,
                budgetCount: 0,
                debtCount: 0,
                savingsGoalCount: 0,
                splitGroupCount: 0,
                documentCount: 0,
                payeeCount: 0,
                recurringRuleCount: 0,
                recentErrors: entries
            )
        )
        #expect(rendered.contains("AddTransactionUseCase.execute"))
        #expect(rendered.contains("ValidationError"))
        #expect(!rendered.contains("DoorDash"))
        #expect(!rendered.contains("15.49"))

        store.clear()
        #expect(store.recentEntries().isEmpty)
    }

    @Test("PrivacyInfo.xcprivacy still declares zero collected data types and tracking domains")
    func privacyManifestDeclaresZeroCollectedTypes() throws {
        // #filePath → …/VittoraTests/Features/Settings/SupportDiagnosticsTests.swift
        let privacyURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Settings
            .deletingLastPathComponent() // Features
            .deletingLastPathComponent() // VittoraTests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Vittora/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: privacyURL)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dict = try #require(plist as? [String: Any])

        let collected = try #require(dict["NSPrivacyCollectedDataTypes"] as? [Any])
        #expect(collected.isEmpty)

        let trackingDomains = try #require(dict["NSPrivacyTrackingDomains"] as? [Any])
        #expect(trackingDomains.isEmpty)

        let tracking = try #require(dict["NSPrivacyTracking"] as? Bool)
        #expect(tracking == false)
    }

    @Test("support email constant is present for the mail composer path")
    func supportEmailConstantExists() {
        #expect(DiagnosticPayload.supportEmail == "support@vittora.app")
    }

    @Test("DiagnosticSnapshotBuilder from demo dataset omits amounts, notes, payees, account and category names")
    @MainActor
    func builderPayloadOmitsSensitiveDemoFields() async throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let accountRepo = SwiftDataAccountRepository(modelContainer: container)
        let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
        let budgetRepo = SwiftDataBudgetRepository(modelContainer: container)
        let savingsRepo = SwiftDataSavingsGoalRepository(modelContainer: container)
        let debtRepo = SwiftDataDebtRepository(modelContainer: container)
        let recurringRepo = SwiftDataRecurringRuleRepository(modelContainer: container)
        let payeeRepo = SwiftDataPayeeRepository(modelContainer: container)
        let splitGroupRepo = SwiftDataSplitGroupRepository(modelContainer: container)
        let taxProfileRepo = SwiftDataTaxProfileRepository(modelContainer: container)
        let ledger = LedgerWriteStore(modelContainer: container)
        let seeder = DefaultDataSeeder(modelContainer: container)

        let demo = UITestDataSeeder(
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            transactionRepository: transactionRepo,
            ledgerWriting: ledger
        )
        try await demo.seedDemoShowcaseIfNeeded(
            budgetRepository: budgetRepo,
            savingsGoalRepository: savingsRepo,
            debtRepository: debtRepo,
            recurringRuleRepository: recurringRepo,
            payeeRepository: payeeRepo,
            splitGroupRepository: splitGroupRepo,
            taxProfileRepository: taxProfileRepo,
            dataSeeder: seeder
        )

        let accounts = try await accountRepo.fetchAll()
        let categories = try await categoryRepo.fetchAll()
        let payees = try await payeeRepo.fetchAll()
        let transactions = try await transactionRepo.fetchAll(filter: nil)
        #expect(!accounts.isEmpty)
        #expect(!transactions.isEmpty)

        let errorSuite = "SupportDiagnosticsTests.builder.\(UUID().uuidString)"
        let errorDefaults = UserDefaults(suiteName: errorSuite)!
        defer { errorDefaults.removePersistentDomain(forName: errorSuite) }
        let errorLog = RecentErrorLogStore(defaults: errorDefaults)
        errorLog.record(errorType: "TestError", codePath: "SupportDiagnosticsTests.builder")

        let syncKey = AppUserDefaults.StandardKey.cloudSyncEnabled
        let previousSync = UserDefaults.standard.object(forKey: syncKey)
        UserDefaults.standard.set(false, forKey: syncKey)
        defer {
            if let previousSync {
                UserDefaults.standard.set(previousSync, forKey: syncKey)
            } else {
                UserDefaults.standard.removeObject(forKey: syncKey)
            }
        }

        let service = DataManagementService(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            budgetRepository: budgetRepo,
            debtRepository: debtRepo,
            savingsGoalRepository: savingsRepo,
            splitGroupRepository: MockSplitGroupRepository(),
            documentRepository: MockDocumentRepository(),
            keychainService: MockKeychainService()
        )
        let stats = try await service.fetchStats()
        let settingsVM = SettingsViewModel(keychainService: MockKeychainService())
        let snapshot = DiagnosticSnapshotBuilder.make(
            settingsVM: settingsVM,
            stats: stats,
            payeeCount: payees.count,
            recurringRuleCount: try await recurringRepo.fetchAll().count,
            errorLog: errorLog
        )
        let payload = DiagnosticPayload.render(snapshot)

        let forbiddenAmounts = [
            "15.49", "128.40", "96.20", "42.75", "142.10", "48.30", "89.65",
            "28.90", "132.80", "101.50", "36.40", "189.99", "118.25", "24.50",
            "54.20", "52.75", "27.35", "18.60", "6400", "1850", "4200",
        ]
        for amount in forbiddenAmounts {
            #expect(!payload.contains(amount), "payload must not contain amount \(amount)")
        }

        let forbiddenNotes = [
            "Weekly Groceries", "Dinner Delivery", "Groceries Restock", "Netflix",
            "Monthly Salary", "Monthly Rent", "Electric Bill", "Running Shoes",
            "Uber to Airport", "Weekend Brunch", "Movie Night", "Monthly Staples",
            "Pharmacy", "Lunch Order", "Concert tickets", "Gas",
        ]
        for note in forbiddenNotes {
            #expect(!payload.contains(note), "payload must not contain note \(note)")
        }

        for payee in payees {
            #expect(
                !containsWholeWord(payload, payee.name),
                "payload must not contain payee \(payee.name)"
            )
        }
        for account in accounts {
            #expect(
                !containsWholeWord(payload, account.name),
                "payload must not contain account \(account.name)"
            )
        }
        for category in categories {
            #expect(
                !containsWholeWord(payload, category.name),
                "payload must not contain category \(category.name)"
            )
        }

        #expect(payload.contains("Transactions: \(snapshot.transactionCount)"))
        #expect(payload.contains("Accounts: \(snapshot.accountCount)"))
        #expect(payload.contains("Last Sync Result: disabled"))
        #expect(payload.contains(DiagnosticPayload.supportEmail) == false)
    }
}

/// Whole-word match so device model `iPhone17,1` does not false-positive category `Phone`.
private func containsWholeWord(_ haystack: String, _ needle: String) -> Bool {
    guard !needle.isEmpty else { return false }
    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b"
    return haystack.range(of: pattern, options: .regularExpression) != nil
}
