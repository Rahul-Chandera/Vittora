import XCTest

final class CategoryFlowUITests: XCTestCase {

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
    func testTappingCategoryOpensEditForm() throws {
        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Settings", in: app, timeout: 20),
            "Could not open the Settings tab."
        )

        let manageCategories = app.descendants(matching: .any)["settings-manage-categories"]
        XCTAssertTrue(manageCategories.waitForExistence(timeout: 15), "Manage › Categories row missing.")
        UITestSupport.tapWhenReady(manageCategories, timeout: 10)

        // UI-test mode doesn't seed default categories, so create one to tap.
        let addButton = app.buttons["Add Category"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 15), "Add Category button missing.")
        UITestSupport.tapWhenReady(addButton, timeout: 10)

        let nameField = app.textFields["Category Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "Category name field missing.")
        nameField.tap()
        nameField.typeText("Groceries")

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8))
        UITestSupport.tapWhenReady(saveButton, timeout: 8)

        let row = app.descendants(matching: .any)["category-row-groceries"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Created category should be listed.")
        UITestSupport.tapWhenReady(row, timeout: 10)

        // CategoryDetailView loads the category then shows CategoryFormView,
        // titled "Edit Category" — proves the tap opened the editor.
        XCTAssertTrue(
            app.navigationBars["Edit Category"].waitForExistence(timeout: 15),
            "Tapping a category row should open its edit form."
        )
    }
}
