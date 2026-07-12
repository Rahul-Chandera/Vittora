import XCTest

final class TransferFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-transfers"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanTransferFundsFromDashboardQuickAction() throws {
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app),
            "Dashboard should be visible before starting a transfer."
        )

        let transferButton = app.buttons["quick-action-transfer-button"]
        UITestSupport.tapWhenReady(transferButton, timeout: 15)

        let sourceButton = app.buttons["transfer-source-account-button"]
        UITestSupport.tapWhenReady(sourceButton, timeout: 10)

        let accountPicker = app.collectionViews["account-picker-root"]
        XCTAssertTrue(accountPicker.waitForExistence(timeout: 10))

        let sourceAccountRow = app.buttons["transfer-source-account-ui-test-checking"]
        UITestSupport.tapWhenReady(sourceAccountRow, timeout: 10)

        let destinationButton = app.buttons["transfer-destination-account-button"]
        UITestSupport.tapWhenReady(destinationButton, timeout: 10)

        XCTAssertTrue(accountPicker.waitForExistence(timeout: 10))

        let destinationAccountRow = app.buttons["transfer-destination-account-ui-test-savings"]
        UITestSupport.tapWhenReady(destinationAccountRow, timeout: 10)

        let amountField = app.textFields["transfer-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 8))
        amountField.tap()
        amountField.typeText("125")

        let noteField = app.textFields["transfer-note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 8))
        noteField.tap()
        noteField.typeText("Move to savings")

        let submitButton = app.buttons["transfer-submit-button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 8))
        XCTAssertTrue(submitButton.isEnabled)
        UITestSupport.tapWhenReady(submitButton, timeout: 8)

        XCTAssertTrue(
            UITestSupport.waitForDisappearance(sourceButton, timeout: 10),
            "The transfer form should dismiss after a successful transfer."
        )

        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Transactions", in: app, timeout: 15),
            "Transactions tab should be reachable after transfer."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15),
            "Transaction list should load after switching tabs."
        )
        XCTAssertTrue(
            UITestSupport.waitForTransactionRowCount(in: app, 2, timeout: 20),
            "A transfer should create the paired debit and credit entries in the transaction list."
        )
    }
}
