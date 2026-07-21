import CoreSpotlight
import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Transaction Spotlight Deep Link Tests")
struct TransactionSpotlightDeepLinkTests {

    @Test("builds and parses transaction Spotlight URLs")
    func roundTrip() {
        let id = UUID()
        let url = TransactionSpotlightDeepLink.url(for: id)

        #expect(url.scheme == "vittora")
        #expect(url.host == "transaction")
        #expect(TransactionSpotlightDeepLink.isTransactionURL(url))
        #expect(TransactionSpotlightDeepLink.transactionID(from: url) == id)
    }

    @Test("malformed transaction URLs return nil")
    func rejectsMalformed() {
        let samples = [
            "vittora://transaction/",
            "vittora://transaction/not-a-uuid",
            "vittora://add?type=expense",
            "https://example.com",
        ]
        for sample in samples {
            guard let url = URL(string: sample) else {
                Issue.record("URL should parse: \(sample)")
                continue
            }
            #expect(TransactionSpotlightDeepLink.transactionID(from: url) == nil)
        }
    }
}

@Suite("Transaction Spotlight Index Draft Tests")
struct TransactionSpotlightIndexDraftTests {

    @Test("draft title prefers payee; description includes category and amount")
    func draftIncludesPayeeAndCategory() {
        let tx = TransactionEntity(
            amount: Decimal(string: "42.50")!,
            note: "lunch",
            type: .expense,
            currencyCode: "USD"
        )
        let draft = TransactionSpotlightIndex.makeDraft(
            transaction: tx,
            payeeName: "Cafe Nero",
            categoryName: "Dining",
            currencyCode: "USD"
        )

        #expect(draft.title == "Cafe Nero")
        #expect(draft.contentDescription.contains("Dining"))
        #expect(draft.contentDescription.contains("42.50") || draft.contentDescription.contains("42.5"))
        #expect(draft.keywords.contains("Dining"))
        #expect(draft.keywords.contains("Cafe Nero"))
    }

    @Test("draft falls back to note then type when payee missing")
    func draftFallbackTitle() {
        let withNote = TransactionEntity(amount: 10, note: "Metro card", type: .expense)
        #expect(
            TransactionSpotlightIndex.makeDraft(
                transaction: withNote,
                payeeName: nil,
                categoryName: "Transport",
                currencyCode: "USD"
            ).title == "Metro card"
        )

        let bare = TransactionEntity(amount: 10, note: nil, type: .income)
        #expect(
            TransactionSpotlightIndex.makeDraft(
                transaction: bare,
                payeeName: nil,
                categoryName: nil,
                currencyCode: "USD"
            ).title == TransactionType.income.displayName
        )
    }

    @Test("searchable item unique ID is the transaction UUID")
    func searchableItemIdentity() {
        let id = UUID()
        let draft = TransactionSpotlightIndex.ItemDraft(
            id: id,
            title: "Vendor",
            contentDescription: "Food · $1.00 · Jan 1, 2026",
            keywords: ["Food"]
        )
        let item = TransactionSpotlightIndex.searchableItem(from: draft)
        #expect(item.uniqueIdentifier == id.uuidString)
        #expect(item.domainIdentifier == TransactionSpotlightIndex.domainIdentifier)
    }

    @Test("indexing preference defaults ON and can be turned OFF")
    func indexingPreferenceDefaultsOn() {
        let suite = "vittora.tests.spotlight.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        #expect(TransactionSpotlightIndex.isIndexingEnabled(userDefaults: defaults))
        TransactionSpotlightIndex.setIndexingEnabled(false, userDefaults: defaults)
        #expect(TransactionSpotlightIndex.isIndexingEnabled(userDefaults: defaults) == false)
        TransactionSpotlightIndex.setIndexingEnabled(true, userDefaults: defaults)
        #expect(TransactionSpotlightIndex.isIndexingEnabled(userDefaults: defaults))
    }
}

@Suite("AppState Spotlight Routing Tests")
@MainActor
struct AppStateSpotlightRoutingTests {

    @Test("Spotlight URL queues pending transaction detail on the transactions tab")
    func queuesPendingDetail() {
        let state = AppState(selectedTab: .dashboard)
        let id = UUID()

        state.openFromURL(TransactionSpotlightDeepLink.url(for: id))

        #expect(state.pendingTransactionDetailID == id)
        #expect(state.selectedTab == .transactions)
    }

    @Test("openFromSpotlight survives App Lock until cleared after unlock")
    func pendingSurvivesAppLock() {
        let state = AppState(isAuthenticated: false, isLocked: true, selectedTab: .settings)
        let id = UUID()

        state.openFromSpotlight(transactionID: id)

        #expect(state.pendingTransactionDetailID == id)
        #expect(state.selectedTab == .transactions)
        #expect(state.isLocked)

        state.isLocked = false
        state.isAuthenticated = true
        #expect(state.pendingTransactionDetailID == id)

        state.clearPendingTransactionDetailID()
        #expect(state.pendingTransactionDetailID == nil)
    }

    @Test("notifyChanged(.transactions) invokes Spotlight sync hook")
    func notifyChangedWiresSpotlightHook() {
        let state = AppState()
        var hookCount = 0
        state.onTransactionsChangedForSpotlight = { hookCount += 1 }

        state.notifyChanged(.accounts)
        #expect(hookCount == 0)

        state.notifyChanged(.transactions)
        #expect(hookCount == 1)

        state.notifyChanged([.budgets, .transactions])
        #expect(hookCount == 2)
    }

    @Test("CSSearchableItem user activity parses transaction ID")
    func userActivityParsesIdentifier() {
        let id = UUID()
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]

        #expect(TransactionSpotlightIndex.transactionID(fromUserActivity: activity) == id)
    }
}

@Suite("Spotlight Settings Toggle Wiring Tests")
@MainActor
struct SpotlightSettingsToggleWiringTests {

    @Test("SettingsViewModel Spotlight toggle writes the preference key used by the indexer")
    func settingsToggleWritesIndexerPreference() {
        let key = AppUserDefaults.StandardKey.spotlightIndexingEnabled
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let vm = SettingsViewModel(keychainService: MockKeychainService())
        vm.isSpotlightIndexingEnabled = false
        #expect(TransactionSpotlightIndex.isIndexingEnabled() == false)
        #expect(UserDefaults.standard.object(forKey: key) as? Bool == false)

        vm.isSpotlightIndexingEnabled = true
        #expect(TransactionSpotlightIndex.isIndexingEnabled())
    }

    @Test("indexing then deleteAllIndexedTransactions completes (toggle OFF / factory-reset path)")
    func indexThenClearCompletes() async {
        let draft = TransactionSpotlightIndex.ItemDraft(
            id: UUID(),
            title: "Spotlight Clear Probe",
            contentDescription: "Groceries · $1.00 · Jan 1, 2026",
            keywords: ["Groceries"]
        )
        await TransactionSpotlightIndex.index(drafts: [draft], replaceDomain: true)
        await TransactionSpotlightIndex.deleteAllIndexedTransactions()
    }
}
