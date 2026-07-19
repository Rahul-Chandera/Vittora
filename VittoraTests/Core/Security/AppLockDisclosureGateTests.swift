import Foundation
import Testing
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

@Suite("AppLockSessionMirror")
struct AppLockSessionMirrorTests {

    @Test("mirrorFromAppState is unlocked only when authenticated and not locked")
    func mirrorReflectsSession() {
        let key = AppLockSessionMirror.isSessionUnlockedKey
        defer { AppUserDefaults.appGroup.removeObject(forKey: key) }

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: true,
            isAuthenticated: false
        )
        #expect(AppLockSessionMirror.isSessionUnlocked == false)
        #expect(AppLockSessionMirror.isAppLocked == true)

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: true,
            isLocked: false,
            isAuthenticated: true
        )
        #expect(AppLockSessionMirror.isSessionUnlocked == true)
        #expect(AppLockSessionMirror.isAppLocked == false)

        AppLockSessionMirror.mirrorFromAppState(
            isAppLockEnabled: false,
            isLocked: true,
            isAuthenticated: false
        )
        #expect(AppLockSessionMirror.isSessionUnlocked == true)
    }
}

@Suite("TodaySpendingQuery")
struct TodaySpendingQueryTests {

    @Test("run returns unlock message when gated without reading store")
    func runRespectsLockGate() async {
        let message = await TodaySpendingQuery.run(isAppLockEnabled: true, isAppLocked: true)
        #expect(message == AppLockDisclosureGate.unlockRequiredMessage)
    }
}
