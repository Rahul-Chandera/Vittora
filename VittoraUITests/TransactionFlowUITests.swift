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
            listRoot.waitForExistence(timeout: 10),
            "Transaction list should be visible before counting rows."
        )
        let initialTransactionCount = transactionRowCount()

        let addButton = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"]
            : app.buttons["Add Transaction"].firstMatch
        UITestSupport.tapWhenReady(addButton, timeout: 15)

        let amountField = app.textFields["transaction-amount-field"].exists
            ? app.textFields["transaction-amount-field"]
            : app.textFields.firstMatch
        XCTAssertTrue(amountField.waitForExistence(timeout: 8))
        amountField.tap()
        amountField.typeText("42.75")

        let noteField = app.descendants(matching: .any)["transaction-note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 8))
        noteField.tap()
        noteField.typeText("UI Test Dinner")

        let saveButton = app.buttons["transaction-form-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8))
        XCTAssertTrue(saveButton.isEnabled, "The form should be saveable with seeded defaults.")
        UITestSupport.tapWhenReady(saveButton, timeout: 8)

        XCTAssertTrue(
            UITestSupport.waitForDisappearance(amountField, timeout: 8),
            "The transaction form should dismiss after saving."
        )

        let newRow = app.descendants(matching: .any)["transaction-row-ui-test-dinner"]
        XCTAssertTrue(
            newRow.waitForExistence(timeout: 20),
            "The saved transaction row should appear in the list."
        )
        XCTAssertTrue(
            UITestSupport.waitForTransactionRowCount(in: app, initialTransactionCount + 1, timeout: 20),
            "The transaction list should show one additional row after saving a new entry."
        )
    }

    @MainActor
    func testCanSearchAndFilterTransactions() throws {
        navigateToTransactionsTab()
        waitForSeededTransactionRows()

        XCTAssertTrue(
            UITestSupport.waitForElement(app.buttons["transaction-add-button"], timeout: 25, requireHittable: true),
            "Transaction toolbar should finish loading before filtering."
        )
        openFilterSheet()

        let minAmountField = app.textFields["transaction-filter-min-field"]
        XCTAssertTrue(minAmountField.waitForExistence(timeout: 10))
        minAmountField.tap()
        minAmountField.typeText("1000")

        let applyButton = app.buttons["transaction-filter-apply-button"]
        UITestSupport.tapWhenReady(applyButton, timeout: 10)
        XCTAssertTrue(
            waitForFilterSheetDismissed(timeout: 15),
            "Filter sheet should dismiss after applying."
        )

        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-monthly-salary",
                toExist: true,
                timeout: 15
            ),
            "Filtering to the higher amount range should keep the seeded salary transaction."
        )
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-coffee-run",
                toExist: false,
                timeout: 15
            ),
            "Filtering to the higher amount range should hide the seeded coffee transaction."
        )

        openFilterSheet()
        let clearButton = app.buttons["transaction-filter-clear-button"]
        UITestSupport.tapWhenReady(clearButton, timeout: 10)
        UITestSupport.tapWhenReady(applyButton, timeout: 10)
        XCTAssertTrue(
            waitForFilterSheetDismissed(timeout: 15),
            "Filter sheet should dismiss after clearing."
        )
        waitForSeededTransactionRows()

        let searchField = app.searchFields["Search transactions"]
        XCTAssertTrue(
            UITestSupport.waitForElement(searchField, timeout: 12, requireHittable: true),
            "Search field should be ready before typing."
        )
        searchField.tap()
        searchField.typeText("Coffee")

        // Debounced search (250ms) — poll until rows match expected filter state.
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-coffee-run",
                toExist: true,
                timeout: 20
            ),
            "Search should surface the coffee transaction."
        )
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-monthly-salary",
                toExist: false,
                timeout: 20
            ),
            "Search should hide transactions whose notes do not match."
        )
    }

    @MainActor
    private func navigateToTransactionsTab() {
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app),
            "App shell should be visible before opening transactions."
        )

        if waitForTransactionsList(timeout: 5) {
            return
        }

        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Transactions", in: app, timeout: 15),
            "Could not find the Transactions tab."
        )
        XCTAssertTrue(
            waitForTransactionsList(timeout: 20),
            "The transactions list should be visible after selecting the tab."
        )
    }

    @MainActor
    private func waitForSeededTransactionRows() {
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-coffee-run",
                toExist: true,
                timeout: 20
            ),
            "Seeded coffee transaction should appear in the list."
        )
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "transaction-row-monthly-salary",
                toExist: true,
                timeout: 20
            ),
            "Seeded salary transaction should appear in the list."
        )
    }

    @MainActor
    private func openFilterSheet() {
        XCTAssertTrue(
            waitForFilterButton(timeout: 30),
            "Filter button should be visible on the transactions list."
        )
        tapFilterButton()

        let filterSheet = app.descendants(matching: .any)["transaction-filter-sheet"]
        XCTAssertTrue(
            filterSheet.waitForExistence(timeout: 20),
            "Filter sheet should present after tapping filter."
        )
    }

    @MainActor
    private func waitForFilterSheetDismissed(timeout: TimeInterval) -> Bool {
        let filterSheet = app.descendants(matching: .any)["transaction-filter-sheet"]
        return UITestSupport.waitForDisappearance(filterSheet, timeout: timeout)
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
    private func waitForFilterButton(timeout: TimeInterval) -> Bool {
        let filterButton = app.buttons["transaction-filter-button"]
        return UITestSupport.waitForElement(filterButton, timeout: timeout, requireHittable: true)
    }

    @MainActor
    private func tapFilterButton() {
        let filterButton = app.buttons["transaction-filter-button"]
        XCTAssertTrue(
            waitForFilterButton(timeout: 20),
            "Filter button should be ready before tapping."
        )
        UITestSupport.tapWhenReady(filterButton, timeout: 8)
    }
}
