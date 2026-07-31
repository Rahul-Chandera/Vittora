import XCTest

final class HindiLocalizationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("Hindi layout verification runs on iPhone Simulator.")
        #else
        app = XCUIApplication()
        #endif
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCoreFlowsAndIndiaTaxRenderInHindi() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchOnboarding()
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 45)
                || app.buttons["onboarding-next-button"].exists
        )
        XCTAssertTrue(app.staticTexts["Vittora में आपका स्वागत है"].waitForExistence(timeout: 15))
        capture(named: "hi-onboarding")

        launchSeeded(initialTab: "dashboard")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["डैशबोर्ड"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "₹")).firstMatch
                .waitForExistence(timeout: 15),
            "The India demo must render formatter-backed INR values."
        )
        capture(named: "hi-dashboard")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "ट्रांज़ैक्शन", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        capture(named: "hi-transaction-list")

        let rowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")
        let row = app.descendants(matching: .any).matching(rowPredicate).firstMatch
        UITestSupport.tapWhenReady(row, timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-detail-root"].waitForExistence(timeout: 10)
        )
        capture(named: "hi-transaction-detail")
        app.navigationBars.buttons.firstMatch.tap()

        UITestSupport.tapWhenReady(app.buttons["transaction-add-button"], timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-form-root"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.navigationBars["नया ट्रांज़ैक्शन"].exists)
        capture(named: "hi-add-transaction")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "बजट", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["budget-list-root"].waitForExistence(timeout: 15)
        )
        capture(named: "hi-budgets")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "रिपोर्ट", in: app))
        XCTAssertTrue(app.navigationBars["रिपोर्ट"].waitForExistence(timeout: 15))
        capture(named: "hi-reports")

        let monthlyCard = app.descendants(matching: .any)["report-card-monthly"].firstMatch
        UITestSupport.scrollToElement(monthlyCard, in: app)
        UITestSupport.tapWhenReady(monthlyCard, timeout: 15)
        XCTAssertTrue(app.navigationBars["मासिक अवलोकन"].waitForExistence(timeout: 15))
        capture(named: "hi-monthly-overview")

        launchSeeded(initialTab: "savings")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["बचत"], timeout: 15)
        XCTAssertTrue(app.navigationBars["बचत लक्ष्य"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "₹1,50,000"))
                .firstMatch.waitForExistence(timeout: 15),
            "INR values must retain formatter-provided Indian digit grouping."
        )
        capture(named: "hi-savings")

        launchSeeded(initialTab: "tax")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["टैक्स"], timeout: 15)
        XCTAssertTrue(app.navigationBars["टैक्स कैलकुलेटर"].waitForExistence(timeout: 15))
        // Demo seed includes an India tax profile so audits and localization both
        // exercise the populated estimator.
        XCTAssertTrue(app.staticTexts["टैक्स ब्रैकेट वितरण"].waitForExistence(timeout: 15))
        capture(named: "hi-india-tax-dashboard")

        let taxProfileButton = app.buttons["tax-profile-button"]
        XCTAssertTrue(taxProfileButton.waitForExistence(timeout: 10))
        XCTAssertTrue(
            taxProfileButton.label.contains("प्रोफ़ाइल"),
            "Tax profile control must expose a Hindi accessibility label, not only an identifier."
        )
        UITestSupport.tapWhenReady(taxProfileButton, timeout: 10)
        XCTAssertTrue(app.navigationBars["टैक्स प्रोफ़ाइल"].waitForExistence(timeout: 10))
        let regimePicker = app.buttons["कर व्यवस्था, नई कर व्यवस्था"]
        XCTAssertTrue(regimePicker.waitForExistence(timeout: 10))
        capture(named: "hi-india-tax-profile")

        // Unseeded launch keeps coverage of the Hindi empty state that the demo
        // seed no longer reaches.
        launchUnseeded(initialTab: "tax")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["टैक्स"], timeout: 15)
        XCTAssertTrue(app.staticTexts["कोई टैक्स प्रोफ़ाइल नहीं"].waitForExistence(timeout: 15))
        capture(named: "hi-india-tax-empty")
        #endif
    }

    @MainActor
    private func launchOnboarding() {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-onboarding",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(hi)",
            "-AppleLocale", "hi_IN"
        ]
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    @MainActor
    private func launchSeeded(initialTab: String) {
        if app.state != .notRunning {
            app.terminate()
        }
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-seed-demo",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(hi)",
            "-AppleLocale", "hi_IN"
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        app.launchEnvironment["UITEST_DEMO_REGION"] = "IN"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    @MainActor
    private func launchUnseeded(initialTab: String) {
        if app.state != .notRunning {
            app.terminate()
        }
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(hi)",
            "-AppleLocale", "hi_IN"
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        app.launchEnvironment["UITEST_DEMO_REGION"] = "IN"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    private func capture(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("verification", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
