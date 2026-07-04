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
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app),
            "App shell should be visible before opening budgets."
        )
        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Budgets", in: app, timeout: 15),
            "Budgets tab should be reachable."
        )

        XCTAssertTrue(
            app.staticTexts["No Budgets Yet"].waitForExistence(timeout: 10),
            "The budget screen should start empty in UI test mode."
        )

        let addButton = app.buttons["budget-add-button"]
        UITestSupport.tapWhenReady(addButton, timeout: 10)

        let amountField = app.textFields["budget-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 8))
        amountField.tap()
        amountField.typeText("250")

        let saveButton = app.buttons["budget-save-button"]
        UITestSupport.tapWhenReady(saveButton, timeout: 8)

        XCTAssertTrue(
            UITestSupport.waitForDisappearance(amountField, timeout: 8),
            "The budget form should dismiss after saving."
        )
        XCTAssertFalse(
            app.staticTexts["No Budgets Yet"].waitForExistence(timeout: 5),
            "The empty state should disappear after creating a budget."
        )
    }
}
