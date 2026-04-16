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
        let transferButton = app.buttons["quick-action-transfer-button"]
        XCTAssertTrue(transferButton.waitForExistence(timeout: 5))
        transferButton.tap()

        let sourceButton = app.buttons["transfer-source-account-button"]
        XCTAssertTrue(sourceButton.waitForExistence(timeout: 5))
        sourceButton.tap()

        let accountPicker = app.collectionViews["account-picker-root"]
        XCTAssertTrue(accountPicker.waitForExistence(timeout: 5))

        let sourceAccountRow = app.buttons["transfer-source-account-ui-test-checking"]
        XCTAssertTrue(sourceAccountRow.waitForExistence(timeout: 5))
        sourceAccountRow.tap()

        let destinationButton = app.buttons["transfer-destination-account-button"]
        XCTAssertTrue(destinationButton.waitForExistence(timeout: 5))
        destinationButton.tap()

        XCTAssertTrue(accountPicker.waitForExistence(timeout: 5))

        let destinationAccountRow = app.buttons["transfer-destination-account-ui-test-savings"]
        XCTAssertTrue(destinationAccountRow.waitForExistence(timeout: 5))
        destinationAccountRow.tap()

        let amountField = app.textFields["transfer-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("125")

        let noteField = app.textFields["transfer-note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        noteField.tap()
        noteField.typeText("Move to savings")

        let submitButton = app.buttons["transfer-submit-button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()

        XCTAssertFalse(
            sourceButton.waitForExistence(timeout: 1),
            "The transfer form should dismiss after a successful transfer."
        )

        let transactionsTab = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 5))
        transactionsTab.tap()

        XCTAssertTrue(
            waitForTransactionRowCount(2, timeout: 5),
            "A transfer should create the paired debit and credit entries in the transaction list."
        )
    }

    @MainActor
    private func waitForTransactionRowCount(_ expectedCount: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let rowCount = app
                .descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-"))
                .count

            if rowCount == expectedCount {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return false
    }
}
