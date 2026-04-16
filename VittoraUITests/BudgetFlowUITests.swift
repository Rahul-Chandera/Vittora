import XCTest

final class BudgetFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanCreateBudgetFromEmptyState() throws {
        let budgetsTab = app.tabBars.buttons["Budgets"]
        XCTAssertTrue(budgetsTab.waitForExistence(timeout: 5))
        budgetsTab.tap()

        XCTAssertTrue(
            app.staticTexts["No Budgets Yet"].waitForExistence(timeout: 5),
            "The budget screen should start empty in UI test mode."
        )

        let addButton = app.buttons["budget-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let amountField = app.textFields["budget-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("250")

        let saveButton = app.buttons["budget-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertFalse(
            amountField.waitForExistence(timeout: 1),
            "The budget form should dismiss after saving."
        )
        XCTAssertFalse(
            app.staticTexts["No Budgets Yet"].waitForExistence(timeout: 3),
            "The empty state should disappear after creating a budget."
        )
    }
}
