import XCTest

final class TransactionFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-seed-transactions"]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "transactions"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanAddTransactionFromTransactionsTab() throws {
        navigateToTransactionsTab()

        let coffeeRow = app.descendants(matching: .any)["transaction-row-coffee-run"]
        XCTAssertTrue(
            coffeeRow.waitForExistence(timeout: 15),
            "Seeded transactions should appear before adding a new entry."
        )

        let listRoot = app.descendants(matching: .any)["transaction-list-root"]
        XCTAssertTrue(
            listRoot.waitForExistence(timeout: 5),
            "Transaction list should be visible before counting rows."
        )
        let initialTransactionCount = listRoot
            .descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-"))
            .count

        let addButton = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"]
            : app.buttons["Add Transaction"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
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
            amountField.waitForExistence(timeout: 3),
            "The transaction form should dismiss after saving."
        )

        let newRow = app.descendants(matching: .any)["transaction-row-ui-test-dinner"]
        XCTAssertTrue(
            newRow.waitForExistence(timeout: 20),
            "The saved transaction row should appear in the list."
        )
        XCTAssertTrue(
            waitForTransactionRowCount(initialTransactionCount + 1, timeout: 15),
            "The transaction list should show one additional row after saving a new entry."
        )
    }

    @MainActor
    func testCanSearchAndFilterTransactions() throws {
        navigateToTransactionsTab()

        let coffeeRow = app.descendants(matching: .any)["transaction-row-coffee-run"]
        let salaryRow = app.descendants(matching: .any)["transaction-row-monthly-salary"]
        XCTAssertTrue(coffeeRow.waitForExistence(timeout: 5))
        XCTAssertTrue(salaryRow.waitForExistence(timeout: 5))

        let searchField = app.searchFields["Search transactions"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Coffee")

        // Debounced search (250ms) — wait for filtered results; no keyboard dismiss needed.
        XCTAssertTrue(coffeeRow.waitForExistence(timeout: 5))
        XCTAssertFalse(
            salaryRow.waitForExistence(timeout: 5),
            "Searching should hide transactions whose notes do not match."
        )

        dismissSearchKeyboardIfNeeded()
        if searchField.buttons["Cancel"].waitForExistence(timeout: 2) {
            searchField.buttons["Cancel"].tap()
        }

        let filterButton = app.buttons["transaction-filter-button"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 10))
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
    private func navigateToTransactionsTab() {
        XCTAssertTrue(
            app.otherElements["content-root"].waitForExistence(timeout: 10),
            "App shell should be visible before opening transactions."
        )

        if waitForTransactionsList(timeout: 3) {
            return
        }

        let transactionsTab = app.tabBars.buttons["Transactions"]
        let transactionsButton = app.buttons["Transactions"].firstMatch

        if transactionsTab.waitForExistence(timeout: 5) {
            transactionsTab.tap()
        } else if transactionsButton.waitForExistence(timeout: 5) {
            transactionsButton.tap()
        } else if app.tabBars.buttons["More"].waitForExistence(timeout: 3) {
            app.tabBars.buttons["More"].tap()
            XCTAssertTrue(
                app.buttons["Transactions"].waitForExistence(timeout: 5),
                "Transactions should appear in the tab overflow menu."
            )
            app.buttons["Transactions"].tap()
        } else {
            XCTFail("Could not find the Transactions tab.")
            return
        }

        XCTAssertTrue(
            waitForTransactionsList(timeout: 15),
            "The transactions list should be visible after selecting the tab."
        )
    }

    @MainActor
    private func waitForTransactionsList(timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: timeout)
    }

    @MainActor
    private func transactionRowCount() -> Int {
        let listRoot = app.descendants(matching: .any)["transaction-list-root"]
        guard listRoot.exists else { return 0 }
        return listRoot.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-"))
            .count
    }

    @MainActor
    private func waitForTransactionRowCount(_ expectedCount: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if transactionRowCount() == expectedCount {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return transactionRowCount() == expectedCount
    }

    @MainActor
    private func dismissSearchKeyboardIfNeeded() {
        if app.keyboards.count > 0 {
            if app.keyboards.buttons["Search"].exists {
                app.keyboards.buttons["Search"].tap()
            } else if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            } else {
                app.tap()
            }
        }
    }
}
