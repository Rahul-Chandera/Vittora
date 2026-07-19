import Foundation
import Testing
import SwiftData
import VittoraCore

@Suite("AppLockDisclosureGate")
struct AppLockDisclosureGateTests {

    @Test("blocks disclosure when App Lock is enabled and locked")
    func blocksWhenEnabledAndLocked() {
        #expect(
            AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: true, isAppLocked: true)
        )
    }

    @Test("allows disclosure when App Lock is enabled but unlocked")
    func allowsWhenEnabledAndUnlocked() {
        #expect(
            !AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: true, isAppLocked: false)
        )
    }

    @Test("allows disclosure when App Lock is disabled even if locked flag is set")
    func allowsWhenDisabled() {
        #expect(
            !AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: false, isAppLocked: true)
        )
        #expect(
            !AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: false, isAppLocked: false)
        )
    }

    @Test("locked gate returns unlock message and never an amount")
    func lockedReturnsUnlockMessage() {
        let amount = Decimal(string: "132.50") ?? 0
        let message = AppLockDisclosureGate.todaySpendingMessage(
            isAppLockEnabled: true,
            isAppLocked: true,
            amount: amount,
            currencyCode: "USD"
        )

        #expect(message == AppLockDisclosureGate.unlockRequiredMessage)
        #expect(!message.contains("132"))
        #expect(!message.contains("$"))
    }

    @Test("unlocked gate returns formatted spending summary")
    func unlockedReturnsSpendingSummary() {
        let amount = Decimal(string: "132.50") ?? 0
        let message = AppLockDisclosureGate.todaySpendingMessage(
            isAppLockEnabled: true,
            isAppLocked: false,
            amount: amount,
            currencyCode: "USD"
        )

        let expectedAmount = amount.formatted(.currency(code: "USD"))
        #expect(message == "You've spent \(expectedAmount) today.")
        #expect(message.contains(expectedAmount))
    }

    @Test("disabled lock returns spending summary")
    func disabledReturnsSpendingSummary() {
        let amount = Decimal(string: "15.49") ?? 0
        let message = AppLockDisclosureGate.todaySpendingMessage(
            isAppLockEnabled: false,
            isAppLocked: true,
            amount: amount,
            currencyCode: "USD"
        )

        let expectedAmount = amount.formatted(.currency(code: "USD"))
        #expect(message == "You've spent \(expectedAmount) today.")
    }
}

@Suite("AppLockSessionMirror", .serialized)
struct AppLockSessionMirrorTests {

    private func resetMirror() {
        AppLockSessionMirror.clearAll()
    }

    @Test("mirrorFromAppState is unlocked only when authenticated and not locked")
    func mirrorReflectsSession() {
        defer { resetMirror() }

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: true,
            isAuthenticated: false,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )
        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(isAppLockEnabled: true) == true
        )

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )
        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(isAppLockEnabled: true) == false
        )

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: false,
            isLocked: true,
            isAuthenticated: false,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )
        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(isAppLockEnabled: false) == false
        )
    }

    @Test("unlocked then backgrounded past timeout blocks disclosure via mirrored policy")
    func unlockedBackgroundedBlocksViaPolicyMirror() {
        defer { resetMirror() }

        // Foreground unlocked session (ContentView mirror path).
        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )
        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(isAppLockEnabled: true) == false
        )

        // Background / force-quit: isLocked does not change, so ContentView onChange
        // never fires — only the scenePhase → mirrorBackgrounded path updates policy.
        let backgroundedAt = Date(timeIntervalSince1970: 1_700_000_000)
        AppLockSessionMirror.mirrorBackgrounded(
            at: backgroundedAt,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )

        let afterTimeout = backgroundedAt.addingTimeInterval(300)
        let locked = AppLockSessionMirror.evaluateIsAppLocked(
            isAppLockEnabled: true,
            now: afterTimeout
        )
        #expect(locked == true)
        #expect(
            AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: true, isAppLocked: locked)
        )
        #expect(
            AppLockDisclosureGate.todaySpendingMessage(
                isAppLockEnabled: true,
                isAppLocked: locked,
                amount: 132.50,
                currencyCode: "USD"
            ) == AppLockDisclosureGate.unlockRequiredMessage
        )
    }

    @Test("unlocked then brief background within timeout still allows disclosure")
    func briefBackgroundWithinTimeoutAllowsDisclosure() {
        defer { resetMirror() }

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )

        let backgroundedAt = Date(timeIntervalSince1970: 1_700_000_000)
        AppLockSessionMirror.mirrorBackgrounded(
            at: backgroundedAt,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )

        let withinTimeout = backgroundedAt.addingTimeInterval(60)
        let locked = AppLockSessionMirror.evaluateIsAppLocked(
            isAppLockEnabled: true,
            now: withinTimeout
        )
        #expect(locked == false)
        #expect(
            !AppLockDisclosureGate.blocksDisclosure(isAppLockEnabled: true, isAppLocked: locked)
        )
    }

    @Test("immediate timeout locks as soon as backgrounded")
    func immediateTimeoutLocksOnBackground() {
        defer { resetMirror() }

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true,
            timeout: AppLockTimeout.immediately.timeInterval
        )

        let backgroundedAt = Date(timeIntervalSince1970: 1_700_000_000)
        AppLockSessionMirror.mirrorBackgrounded(
            at: backgroundedAt,
            timeout: AppLockTimeout.immediately.timeInterval
        )

        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(
                isAppLockEnabled: true,
                now: backgroundedAt
            ) == true
        )
    }

    @Test("missing timeout while App Lock enabled is fail-closed")
    func missingTimeoutIsFailClosed() {
        defer { resetMirror() }

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true,
            timeout: AppLockTimeout.fiveMinutes.timeInterval
        )
        AppUserDefaults.appGroup.removeObject(forKey: AppLockSessionMirror.timeoutIntervalKey)

        #expect(
            AppLockSessionMirror.evaluateIsAppLocked(isAppLockEnabled: true) == true
        )
    }
}

@Suite("TodaySpendingQuery")
struct TodaySpendingQueryTests {

    @Test("run returns unlock message when gated without reading store")
    func runRespectsLockGate() async {
        let message = await TodaySpendingQuery.run(isAppLockEnabled: true, isAppLocked: true)
        #expect(message == AppLockDisclosureGate.unlockRequiredMessage)
    }

    @Test("run formats today's spending from an injected provider")
    func runFormatsProviderAmount() async throws {
        let container = try ModelContainerConfig.makePreviewContainer()
        let provider = WidgetDataProvider(container: container)
        let repo = SwiftDataTransactionRepository(modelContainer: container)
        let amount = Decimal(string: "132.50") ?? 0
        try await repo.create(TransactionEntity(amount: amount, date: .now, type: .expense))

        let message = await TodaySpendingQuery.run(
            isAppLockEnabled: false,
            isAppLocked: false,
            provider: provider
        )

        let expected = AppLockDisclosureGate.todaySpendingMessage(
            isAppLockEnabled: false,
            isAppLocked: false,
            amount: amount,
            currencyCode: CurrencyDefaults.code
        )
        #expect(message == expected)
    }
}
