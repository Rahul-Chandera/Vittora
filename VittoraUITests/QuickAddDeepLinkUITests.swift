import XCTest

/// W4 verification: deep-link routing into quick-add forms.
///
/// Uses `--ui-test-quick-add=` so the same `AppState.openFromURL` path runs without
/// depending on the Simulator "Open in Vittora?" confirmation dialog.
final class QuickAddDeepLinkUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        // Clear Keychain/App Group App Lock so later cases/suites do not inherit it.
        UITestSupport.resetPersistedAppLockStateFromTearDown()
        app = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testExpenseDeepLinkOpensTransactionForm() throws {
        #if !os(iOS)
        throw XCTSkip("Deep link UI tests run on iOS Simulator only")
        #else
        launchWithQuickAdd("expense")

        XCTAssertTrue(
            formRoot("transaction-form-root").waitForExistence(timeout: 10),
            "Expense deep link should present New Transaction"
        )
        XCTAssertTrue(app.navigationBars["New Transaction"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Expense"].waitForExistence(timeout: 3))

        attachScreenshot(name: "deeplink-expense")
        #endif
    }

    @MainActor
    func testIncomeDeepLinkOpensTransactionForm() throws {
        #if !os(iOS)
        throw XCTSkip("Deep link UI tests run on iOS Simulator only")
        #else
        launchWithQuickAdd("income")

        XCTAssertTrue(
            formRoot("transaction-form-root").waitForExistence(timeout: 10),
            "Income deep link should present New Transaction"
        )
        XCTAssertTrue(app.buttons["Income"].waitForExistence(timeout: 3))

        attachScreenshot(name: "deeplink-income")
        #endif
    }

    @MainActor
    func testTransferDeepLinkOpensTransferForm() throws {
        #if !os(iOS)
        throw XCTSkip("Deep link UI tests run on iOS Simulator only")
        #else
        launchWithQuickAdd("transfer")

        XCTAssertTrue(
            formRoot("transfer-form-root").waitForExistence(timeout: 10),
            "Transfer deep link should present Transfer Funds"
        )
        XCTAssertTrue(app.navigationBars["Transfer Funds"].waitForExistence(timeout: 3))

        attachScreenshot(name: "deeplink-transfer")
        #endif
    }

    @MainActor
    func testUnknownQuickAddDoesNotPresentForm() throws {
        #if !os(iOS)
        throw XCTSkip("Deep link UI tests run on iOS Simulator only")
        #else
        launchWithQuickAdd("unknown")

        sleep(2)
        XCTAssertFalse(formRoot("transaction-form-root").exists)
        XCTAssertFalse(formRoot("transfer-form-root").exists)
        XCTAssertTrue(app.otherElements["content-root"].exists)

        attachScreenshot(name: "deeplink-malformed")
        #endif
    }

    @MainActor
    func testAppLockBlocksQuickAddUntilMainUIMounts() throws {
        #if !os(iOS)
        throw XCTSkip("Deep link UI tests run on iOS Simulator only")
        #else
        app.launchArguments = [
            "--uitesting",
            "--ui-test-app-lock",
            "--ui-test-quick-add=expense",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        let lockRoot = app.otherElements["app-lock-root"]
        let lockTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Locked")
        ).firstMatch
        let lockAppeared = lockRoot.waitForExistence(timeout: 10)
            || lockTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(lockAppeared, "App lock screen should appear after background")
        XCTAssertFalse(
            formRoot("transaction-form-root").exists,
            "Quick add must not present while locked"
        )

        attachScreenshot(name: "deeplink-app-lock-gated")
        #endif
    }

    // MARK: - Helpers

    @MainActor
    private func launchWithQuickAdd(_ type: String) {
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "--ui-test-quick-add=\(type)",
        ]
        app.launch()
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app, timeout: 15))
    }

    @MainActor
    private func formRoot(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func attachScreenshot(name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = shot.pngRepresentation
        let dir = URL(fileURLWithPath: "/Volumes/Data/Projects/Vittora/Vittora-worktrees/w4/verification")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
