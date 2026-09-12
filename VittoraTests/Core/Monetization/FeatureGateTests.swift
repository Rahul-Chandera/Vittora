import Foundation
import Testing
@testable import Vittora

private struct StubConversionEventTracker: ConversionEventTracking, Sendable {
    let scansThisMonth: Int

    nonisolated func record(_ milestone: ConversionMilestone) -> ConversionEventResult {
        ConversionEventResult(milestone: milestone, isFirstTime: false, shouldPresentPaywall: false)
    }

    nonisolated func shouldPresentPaywall(for milestone: ConversionMilestone) -> Bool { false }

    nonisolated func markPaywallPresented(for milestone: ConversionMilestone) {}

    nonisolated func hasRecorded(_ milestone: ConversionMilestone) -> Bool { false }

    nonisolated func recordOCRScan() -> ConversionEventResult {
        ConversionEventResult(milestone: .firstOCRScan, isFirstTime: false, shouldPresentPaywall: false)
    }

    nonisolated func ocrScansThisMonth() -> Int { scansThisMonth }
}

@Suite("Feature Gate Tests")
struct FeatureGateTests {
    @Test("everything is unlocked while StoreKit is disabled")
    func unlockedWhileStoreKitDisabled() {
        let gate = FeatureGate(
            levelProvider: { .free },
            ocrScansUsedThisMonth: { 99 },
            storeKitEnabled: false
        )
        #expect(gate.isProUnlocked == true)
        #expect(gate.canScanReceipt == true)
    }

    @Test("a free user is locked out once StoreKit is enabled")
    func freeUserLockedOutWhenStoreKitEnabled() {
        let gate = FeatureGate(
            levelProvider: { .free },
            ocrScansUsedThisMonth: { 0 },
            storeKitEnabled: true
        )
        #expect(gate.isProUnlocked == false)
    }

    @Test("a pro user is unlocked")
    func proUserUnlocked() {
        let gate = FeatureGate(
            levelProvider: { .pro },
            ocrScansUsedThisMonth: { 0 },
            storeKitEnabled: true
        )
        #expect(gate.isProUnlocked == true)
    }

    @Test("a free user keeps the first five OCR scans of the month")
    func freeUserOCRQuota() {
        let atFour = FeatureGate(
            levelProvider: { .free },
            ocrScansUsedThisMonth: { 4 },
            storeKitEnabled: true
        )
        #expect(atFour.canScanReceipt == true)

        let atFive = FeatureGate(
            levelProvider: { .free },
            ocrScansUsedThisMonth: { 5 },
            storeKitEnabled: true
        )
        #expect(atFive.canScanReceipt == false)

        let atSix = FeatureGate(
            levelProvider: { .free },
            ocrScansUsedThisMonth: { 6 },
            storeKitEnabled: true
        )
        #expect(atSix.canScanReceipt == false)
    }

    @Test("a pro user scans past the free cap")
    func proUserPastFreeCap() {
        let gate = FeatureGate(
            levelProvider: { .pro },
            ocrScansUsedThisMonth: { 500 },
            storeKitEnabled: true
        )
        #expect(gate.canScanReceipt == true)
    }

    @Test("offline grace boundary end to end through EntitlementStore")
    func offlineGraceBoundaryThroughStore() throws {
        let suiteName = "vittora.test.gate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let expirationDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.annual.rawValue,
            expirationDate: expirationDate,
            isInBillingRetry: false,
            recordedAt: expirationDate
        )
        EntitlementCache(defaults: defaults).save(snapshot)

        let tracker = StubConversionEventTracker(scansThisMonth: 0)

        let insideGraceNow = Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(15 * 86_400))
        let insideStore = EntitlementStore(
            cache: EntitlementCache(defaults: defaults),
            now: { insideGraceNow }
        )
        let insideGate = FeatureGate(store: insideStore, tracker: tracker, storeKitEnabled: true)
        #expect(insideGate.isProUnlocked == true)

        let outsideGraceNow = Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(17 * 86_400))
        let outsideStore = EntitlementStore(
            cache: EntitlementCache(defaults: defaults),
            now: { outsideGraceNow }
        )
        let outsideGate = FeatureGate(store: outsideStore, tracker: tracker, storeKitEnabled: true)
        #expect(outsideGate.isProUnlocked == false)
    }
}
