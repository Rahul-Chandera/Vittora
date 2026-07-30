import XCTest

final class AppLockFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-app-lock"]
        app.launch()
    }

    override func tearDownWithError() throws {
        // Clear Keychain/App Group App Lock so later suites do not inherit it.
        UITestSupport.resetPersistedAppLockStateFromTearDown()
        app = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testLockAppearsAfterBackground() throws {
        #if !os(iOS)
        throw XCTSkip("App lock background UI test runs on iOS Simulator only")
        #else
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 8))

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        let lockRoot = app.otherElements["app-lock-root"]
        let lockTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Locked")
        ).firstMatch
        let lockAppeared = lockRoot.waitForExistence(timeout: 10)
            || lockTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(
            lockAppeared,
            "App lock screen should appear after background when timeout is immediate"
        )
        XCTAssertFalse(app.otherElements["content-root"].exists)
        #endif
    }
}
