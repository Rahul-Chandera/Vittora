import XCTest

/// Deleting a transaction asks first.
///
/// Found by deleting a real transaction while testing the Mac app: one click of
/// the detail screen's toolbar trash erased it outright — no dialog, no undo, no
/// way back. Every other destructive action in the app confirms: the debt entry
/// delete names the amount, Delete All Data requires typed confirmation, and
/// deleting an account that has transactions offers to archive instead. The
/// most frequently used delete was the one with no guard at all.
///
/// Deletion changes carry a test requirement, and this is the level the guard
/// actually lives at — the repository call was never the problem.
final class TransactionDeleteConfirmationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "--ui-test-seed-transactions"
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "transactions"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testDeletingATransactionAsksBeforeErasingIt() throws {
        let row = app.descendants(matching: .any)["transaction-row-coffee-run"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The seeded transaction must exist.")
        UITestSupport.tapWhenReady(row)

        let deleteButton = app.descendants(matching: .any)["transaction-detail-delete-button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 20), "The detail screen must offer delete.")
        UITestSupport.tapWhenReady(deleteButton)

        // The guard itself: tapping the trash must not have deleted anything yet.
        let confirmDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(
            confirmDelete.waitForExistence(timeout: 10),
            "Deleting a transaction must ask for confirmation rather than erasing it on the first tap."
        )

        // Dismissing the confirmation must leave the transaction alone.
        //
        // Asserted on the detail screen rather than the list row: a successful
        // delete calls dismiss(), so the detail surviving is exactly the signal
        // that nothing was deleted. The row itself is not a valid check here —
        // iOS pushes the detail full-screen, so the list is off-screen either
        // way. (On macOS's split view it stays visible, which is what made the
        // manual check look conclusive.)
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            UITestSupport.tapWhenReady(cancel)
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-detail-root"].waitForExistence(timeout: 20),
            "Cancelling must leave the transaction and its detail screen in place."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-detail-delete-button"].exists,
            "The detail screen should still be usable after cancelling."
        )
    }

    @MainActor
    func testConfirmingActuallyDeletes() throws {
        let row = app.descendants(matching: .any)["transaction-row-coffee-run"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "The seeded transaction must exist.")
        UITestSupport.tapWhenReady(row)

        UITestSupport.tapWhenReady(app.descendants(matching: .any)["transaction-detail-delete-button"])
        let confirmDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10), "The confirmation must appear.")
        UITestSupport.tapWhenReady(confirmDelete)

        // The guard must not have turned delete into a no-op.
        let gone = app.descendants(matching: .any)["transaction-row-coffee-run"]
            .waitForNonExistence(timeout: 20)
        XCTAssertTrue(gone, "Confirming must actually delete the transaction.")
    }
}
