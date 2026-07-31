import XCTest

final class OnboardingFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    private func launchOnboardingApp() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-onboarding"]
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
        app.launch()
    }

    @MainActor
    func testCanCompleteOnboardingAndReachDashboard() throws {
        launchOnboardingApp()
        XCTAssertTrue(
            UITestSupport.waitForAppForeground(in: app, timeout: 20),
            "Onboarding UI test should reach the foreground."
        )
        XCTAssertTrue(
            waitForOnboardingShell(timeout: 45),
            "Onboarding root should appear in onboarding UI test mode."
        )
        XCTAssertTrue(
            UITestSupport.waitForIdentifier(
                in: app,
                "onboarding-welcome-title",
                toExist: true,
                timeout: 10
            ),
            "Welcome step should be visible."
        )

        tapNext()

        let currencyButton = app.descendants(matching: .any)["onboarding-currency-USD"]
        XCTAssertTrue(
            UITestSupport.waitForElement(currencyButton, timeout: 10, requireHittable: true),
            "USD currency option should be ready."
        )
        UITestSupport.tapWhenReady(currencyButton, timeout: 10)
        tapNext()

        let nameField = app.textFields["onboarding-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Taylor")
        tapNext()

        XCTAssertTrue(
            UITestSupport.waitForDisappearance(app.keyboards.firstMatch, timeout: 8),
            "Keyboard should auto-dismiss when advancing to the next onboarding step."
        )

        let bankAccountType = app.descendants(matching: .any)["onboarding-account-type-bank"]
        if bankAccountType.waitForExistence(timeout: 5) {
            UITestSupport.tapWhenReady(bankAccountType, timeout: 8)
            tapNext()
        }

        let accountNameField = app.textFields["onboarding-account-name-field"]
        XCTAssertTrue(accountNameField.waitForExistence(timeout: 10))
        accountNameField.tap()
        accountNameField.typeText("Daily Checking")

        let openingBalanceField = app.textFields["onboarding-opening-balance-field"]
        XCTAssertTrue(openingBalanceField.waitForExistence(timeout: 10))
        openingBalanceField.tap()
        openingBalanceField.typeText("1000")
        dismissKeyboardIfNeeded()

        tapNextWhenEnabled(timeout: 20)

        XCTAssertTrue(
            waitForOnboardingStep("onboarding-notifications-step", timeout: 25),
            "Should advance to the notifications step after account setup."
        )
        tapNext()

        let nextButton = app.buttons["onboarding-next-button"]
        let reviewStepExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Start Tracking"),
            object: nextButton
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [reviewStepExpectation], timeout: 25),
            .completed,
            "The review step should appear before finishing onboarding."
        )

        tapNext()

        XCTAssertTrue(
            UITestSupport.waitForDisappearance(
                app.buttons["onboarding-next-button"],
                timeout: 10
            ),
            "The onboarding CTA should be dismissed after finishing the flow."
        )
        XCTAssertTrue(
            UITestSupport.waitForElement(
                app.tabBars.buttons["Transactions"],
                timeout: 20,
                requireHittable: false
            ),
            "The main app tab bar should appear after onboarding completes."
        )
        XCTAssertTrue(
            UITestSupport.waitForContentRoot(in: app, timeout: 15),
            "Main app content should be visible after onboarding."
        )
    }

    @MainActor
    private func waitForOnboardingShell(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.otherElements["onboarding-root"].exists
                || app.buttons["onboarding-next-button"].exists
                || app.staticTexts["onboarding-welcome-title"].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return app.otherElements["onboarding-root"].exists
            || app.buttons["onboarding-next-button"].exists
            || app.staticTexts["onboarding-welcome-title"].exists
    }

    @MainActor
    private func tapNext() {
        let nextButton = app.buttons["onboarding-next-button"]
        UITestSupport.tapWhenReady(nextButton, timeout: 10)
    }

    @MainActor
    private func tapNextWhenEnabled(timeout: TimeInterval) {
        let nextButton = app.buttons["onboarding-next-button"]
        XCTAssertTrue(
            UITestSupport.waitForElement(nextButton, timeout: timeout, requireHittable: false),
            "Next button should exist before waiting for enablement."
        )
        let enabledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: nextButton
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabledExpectation], timeout: timeout),
            .completed,
            "Next button should become enabled before advancing."
        )
        UITestSupport.tapWhenReady(nextButton, timeout: 8)
    }

    @MainActor
    private func waitForOnboardingStep(_ identifier: String, timeout: TimeInterval) -> Bool {
        UITestSupport.waitForIdentifier(in: app, identifier, toExist: true, timeout: timeout)
    }

    @MainActor
    private func dismissKeyboardIfNeeded() {
        let toolbarDone = app.toolbars.buttons["Done"]
        if toolbarDone.waitForExistence(timeout: 3) {
            UITestSupport.tapWhenReady(toolbarDone, timeout: 5)
        }
    }
}
