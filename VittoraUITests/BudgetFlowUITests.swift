import XCTest

final class BudgetFlowUITests: XCTestCase {

    var app: XCUIApplication!

    /// Deliberately does NOT launch. Launching here and relaunching inside a
    /// test breaks demo seeding: the seeder bails when accounts already exist,
    /// so the second launch came up with no categories at all.
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(seedDemo: Bool, initialTab: String? = nil) {
        app.launchArguments = seedDemo
            ? ["--uitesting", "--ui-test-seed-demo"]
            : ["--uitesting"]
        if let initialTab {
            app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCanCreateBudgetFromEmptyState() throws {
        launch(seedDemo: false)
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

    /// Reported from device: a budget row's progress and spent figure do not
    /// move after adding an expense in that category — only after relaunching.
    ///
    /// The assertion reads the card's accessibility label, which is built from
    /// `budget.spent` and `budget.progress`, so it fails for the same reason the
    /// visible bar and amounts do rather than testing a parallel code path.
    @MainActor
    func testBudgetRowReflectsANewExpenseWithoutRelaunch() throws {
        throw XCTSkip("""
            Written to reproduce the device report, but blocked on the harness \
            rather than on the app, so it is skipped instead of left red for \
            the wrong reason.

            Under --ui-test-seed-demo the transaction form's category Picker \
            offers only its "None" placeholder — categories.expense is empty — \
            so the expense cannot be assigned a category and the test never \
            reaches its assertion. The store itself is seeded correctly: the \
            Entertainment budget card is present with its category name, and \
            BudgetListView reads categories fine. So the form's own category \
            load is what comes up empty in this configuration.

            The behaviour under test is real and unresolved: a budget row does \
            not update after adding an ordinary expense from the Transactions \
            tab. BudgetListViewModelRefreshTests proves the view model and \
            FetchBudgetsUseCase are correct, so the fault is in the refresh or \
            render path, not the data.

            Un-skip once the form's category load is understood.
            """)
        launch(seedDemo: true, initialTab: "budgets")

        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Budgets", in: app, timeout: 15),
            "Budgets tab should be reachable."
        )

        let card = budgetCard(forCategory: "Entertainment")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Seeded Entertainment budget should be listed.")
        let before = card.label

        addExpense(amount: "37", categoryName: "Entertainment")

        XCTAssertTrue(
            UITestSupport.navigateToTab(named: "Budgets", in: app, timeout: 15),
            "Budgets tab should be reachable after saving."
        )

        let updated = budgetCard(forCategory: "Entertainment")
        XCTAssertTrue(updated.waitForExistence(timeout: 20))

        // Poll rather than assert once: the reload is async, and a bare read
        // would race it and fail even when the refresh works.
        let deadline = Date().addingTimeInterval(15)
        var after = updated.label
        while after == before, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            after = budgetCard(forCategory: "Entertainment").label
        }

        XCTAssertNotEqual(
            after,
            before,
            "The Entertainment budget card still reads '\(before)' after a 37 expense in that category. "
            + "It should update without relaunching."
        )
    }

    /// Same defect as the skipped test above, reproduced without touching the
    /// category picker.
    ///
    /// A budget with no category counts every expense against itself (see
    /// `FetchBudgetsUseCase.calculateSpent` — a nil `categoryID` means no
    /// category filter), so an amount-only expense is enough. That sidesteps
    /// the picker that blocks the seeded variant.
    ///
    /// Owner confirmed the row only corrects after a full relaunch — not on a
    /// tab switch — so this asserts the row updates while the app keeps
    /// running.
    @MainActor
    func testBudgetRowUpdatesAfterAnExpenseWithoutCategory() throws {
        // Demo seed, not an empty store: saving a transaction needs an
        // account, and with --uitesting alone the form never dismisses.
        launch(seedDemo: true, initialTab: "budgets")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Budgets", in: app, timeout: 15))

        // Add an UNCATEGORISED budget on top of the seeded ones. Its label
        // begins "Budget budget," because BudgetCardView falls back to
        // "Budget" when there is no category.
        UITestSupport.tapWhenReady(app.buttons["budget-add-button"], timeout: 20)
        let budgetAmount = app.textFields["budget-amount-field"]
        XCTAssertTrue(budgetAmount.waitForExistence(timeout: 15))
        budgetAmount.tap()
        budgetAmount.typeText("500")
        UITestSupport.tapWhenReady(app.buttons["budget-save-button"], timeout: 15)
        XCTAssertTrue(UITestSupport.waitForDisappearance(budgetAmount, timeout: 15))

        let uncategorised = NSPredicate(format: "label BEGINSWITH %@", "Budget budget,")
        let card = app.descendants(matching: .any).matching(uncategorised).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Newly created budget should be listed.")
        UITestSupport.scrollToElement(card, in: app)
        let before = card.label
        let overviewQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Budget overview")).firstMatch
        let overviewBefore = overviewQuery.exists ? overviewQuery.value as? String ?? "nil" : "absent" 

        // Amount-only expense — no category needed.
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transactions", in: app, timeout: 15))
        let addButton = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"]
            : app.buttons["Add Transaction"].firstMatch
        UITestSupport.tapWhenReady(addButton, timeout: 15)
        let amountField = app.textFields["transaction-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 15))
        amountField.tap()
        amountField.typeText("120")
        UITestSupport.tapWhenReady(app.buttons["transaction-form-save-button"], timeout: 15)
        XCTAssertTrue(UITestSupport.waitForDisappearance(amountField, timeout: 15))

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Budgets", in: app, timeout: 15))

        let deadline = Date().addingTimeInterval(15)
        var after = before
        repeat {
            after = app.descendants(matching: .any).matching(uncategorised).firstMatch.label
            if after != before { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        } while Date() < deadline

        // Diagnostic: the overview card and the row are assigned in the SAME
        // loadBudgets() call, so if the header moves and the row does not, the
        // reload ran and the row failed to re-render.
        let overviewAfter = overviewQuery.exists ? overviewQuery.value as? String ?? "nil" : "absent"
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "budgets-after-expense"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertNotEqual(
            after,
            before,
            "Budget card still reads '\(before)' after a 120 expense. "
            + "Overview BEFORE: \(overviewBefore) | AFTER: \(overviewAfter). "
            + "If the overview moved and the row did not, loadBudgets() ran and the row did not re-render."
        )
    }

    // MARK: - Helpers

    @MainActor
    private func firstHittableOption(labelled label: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for query in [app.buttons, app.menuItems, app.staticTexts, app.cells] {
                let candidate = query.matching(NSPredicate(format: "label == %@", label)).firstMatch
                if candidate.exists, candidate.isHittable { return candidate }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        } while Date() < deadline
        return nil
    }

    @MainActor
    private func budgetCard(forCategory name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(name) budget,"))
            .firstMatch
    }

    @MainActor
    private func addExpense(amount: String, categoryName: String) {
        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transactions", in: app, timeout: 15))

        let addButton = app.buttons["transaction-add-button"].exists
            ? app.buttons["transaction-add-button"]
            : app.buttons["Add Transaction"].firstMatch
        UITestSupport.tapWhenReady(addButton, timeout: 15)

        let amountField = app.textFields["transaction-amount-field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 15))
        amountField.tap()
        amountField.typeText(amount)

        let categoryPicker = app.descendants(matching: .any)["transaction-category-picker"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 15))
        // The picker sits below the fold on this form; tapping without
        // scrolling hits nothing and reports "not tappable".
        UITestSupport.scrollToElement(categoryPicker, in: app)
        UITestSupport.tapWhenReady(categoryPicker, timeout: 15)
        // A menu-style Picker exposes its options inconsistently — buttons on
        // some runs, plain menu items or static text on others. Take whichever
        // is hittable rather than assuming one shape.
        let option = firstHittableOption(labelled: categoryName, timeout: 15)
        XCTAssertNotNil(
            option,
            "Category option '\(categoryName)' never became tappable. "
            + "buttons=\(app.buttons.allElementsBoundByIndex.prefix(25).map(\.label)) "
            + "menuItems=\(app.menuItems.allElementsBoundByIndex.prefix(25).map(\.label)) "
            + "cells=\(app.cells.allElementsBoundByIndex.prefix(15).map(\.label))"
        )
        option?.tap()

        UITestSupport.tapWhenReady(app.buttons["transaction-form-save-button"], timeout: 15)
        XCTAssertTrue(
            UITestSupport.waitForDisappearance(amountField, timeout: 15),
            "The transaction form should dismiss after saving."
        )
    }
}
