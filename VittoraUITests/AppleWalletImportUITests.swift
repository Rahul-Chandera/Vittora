import XCTest

/// Import from Apple Wallet (M3.7.1): what a user sees when the import can't
/// run. The simulator has neither the FinanceKit entitlement nor Wallet data,
/// so states are forced with `--ui-test-apple-wallet-state`, which renders them
/// without calling FinanceKit. The authorised flow needs a real iPhone with
/// Apple Card or Apple Cash.
final class AppleWalletImportUITests: XCTestCase {

    @MainActor
    private func launch(state: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-transactions"]
        if let state { app.launchArguments.append("--ui-test-apple-wallet-state=\(state)") }
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "transactions"
        app.launch()
        return app
    }

    @MainActor
    private func openWalletImport(in app: XCUIApplication) {
        UITestSupport.tapWhenReady(app.buttons["transaction-overflow-menu"], timeout: 20)
        UITestSupport.tapWhenReady(app.buttons["transaction-apple-wallet-import"], timeout: 10)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Before Apple grants the entitlement there is no entry point at all.
    @MainActor
    func testNoEntryPointWithoutEntitlement() throws {
        let app = launch(state: nil)
        UITestSupport.tapWhenReady(app.buttons["transaction-overflow-menu"], timeout: 20)
        XCTAssertTrue(app.buttons["Import CSV"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["transaction-apple-wallet-import"].exists)
    }

    @MainActor
    func testUnavailableShowsExplanationInsteadOfImport() throws {
        let app = launch(state: "unavailable")
        openWalletImport(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["apple-wallet-unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["apple-wallet-allow-button"].exists)
        XCTAssertFalse(app.buttons["apple-wallet-import-button"].exists)
    }

    @MainActor
    func testDeniedPointsToSettings() throws {
        let app = launch(state: "denied")
        openWalletImport(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["apple-wallet-denied"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["apple-wallet-import-button"].exists)
    }
}
