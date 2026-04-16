import XCTest

final class TransactionFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-transactions"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanAddTransactionFromTransactionsTab() throws {
        let transactionsTab = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 5))
        transactionsTab.tap()

        let transactionRows = app
            .descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-"))
        let initialTransactionCount = transactionRows.count

        let addButton = app.buttons["Add Transaction"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let amountField = app.textFields["transaction-amount-field"].exists
            ? app.textFields["transaction-amount-field"]
            : app.textFields.firstMatch
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("42.75")

        let noteField = app.descendants(matching: .any)["transaction-note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        noteField.tap()
        noteField.typeText("UI Test Dinner")

        let saveButton = app.buttons["transaction-form-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled, "The form should be saveable with seeded defaults.")
        saveButton.tap()

        XCTAssertFalse(
            amountField.waitForExistence(timeout: 1),
            "The transaction form should dismiss after saving."
        )

        XCTAssertTrue(
            waitForTransactionRowCount(initialTransactionCount + 1, timeout: 5),
            "The transaction list should show one additional row after saving a new entry."
        )
    }

    @MainActor
    func testCanSearchAndFilterTransactions() throws {
        let transactionsTab = app.tabBars.buttons["Transactions"]
        XCTAssertTrue(transactionsTab.waitForExistence(timeout: 5))
        transactionsTab.tap()

        let coffeeRow = app.descendants(matching: .any)["transaction-row-coffee-run"]
        let salaryRow = app.descendants(matching: .any)["transaction-row-monthly-salary"]
        XCTAssertTrue(coffeeRow.waitForExistence(timeout: 5))
        XCTAssertTrue(salaryRow.waitForExistence(timeout: 5))

        let searchField = app.searchFields["Search transactions"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Coffee")
        if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        } else if app.keyboards.count > 0 {
            app.typeText("\n")
        }

        XCTAssertTrue(coffeeRow.waitForExistence(timeout: 5))
        XCTAssertFalse(
            salaryRow.waitForExistence(timeout: 2),
            "Searching should hide transactions whose notes do not match."
        )

        let filterButton = app.buttons["transaction-filter-button"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))
        filterButton.tap()

        let minAmountField = app.textFields["transaction-filter-min-field"]
        XCTAssertTrue(minAmountField.waitForExistence(timeout: 5))
        minAmountField.tap()
        minAmountField.typeText("1000")

        let applyButton = app.buttons["transaction-filter-apply-button"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        applyButton.tap()

        let filteredCoffeeRow = app.descendants(matching: .any)["transaction-row-coffee-run"]
        let filteredSalaryRow = app.descendants(matching: .any)["transaction-row-monthly-salary"]
        XCTAssertTrue(
            filteredSalaryRow.waitForExistence(timeout: 5),
            "Filtering to the higher amount range should keep the seeded salary transaction."
        )
        XCTAssertFalse(
            filteredCoffeeRow.waitForExistence(timeout: 2),
            "Filtering to the higher amount range should hide the seeded coffee transaction."
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
