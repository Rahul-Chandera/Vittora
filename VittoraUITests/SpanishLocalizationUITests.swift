import XCTest

final class SpanishLocalizationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("Spanish layout verification runs on iPhone Simulator.")
        #else
        app = XCUIApplication()
        #endif
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCoreFlowsRenderInSpanish() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchOnboarding()
        XCTAssertTrue(
            app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 45)
                || app.buttons["onboarding-next-button"].exists
        )
        XCTAssertTrue(
            app.staticTexts["Te damos la bienvenida a Vittora"].waitForExistence(timeout: 15),
            "Onboarding must show the Spanish welcome string, not only an accessibility id."
        )
        capture(named: "es-onboarding")

        launchSeeded(initialTab: "dashboard")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Panel"].waitForExistence(timeout: 15))
        capture(named: "es-dashboard")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transacciones", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        capture(named: "es-transaction-list")

        let rowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")
        let row = app.descendants(matching: .any).matching(rowPredicate).firstMatch
        UITestSupport.tapWhenReady(row, timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-detail-root"].waitForExistence(timeout: 10)
        )
        capture(named: "es-transaction-detail")
        app.navigationBars.buttons.firstMatch.tap()

        UITestSupport.tapWhenReady(app.buttons["transaction-add-button"], timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-form-root"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.navigationBars["Nueva transacción"].exists)
        capture(named: "es-add-transaction")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Presupuestos", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["budget-list-root"].waitForExistence(timeout: 15)
        )
        capture(named: "es-budgets")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Informes", in: app))
        XCTAssertTrue(app.navigationBars["Informes"].waitForExistence(timeout: 15))
        capture(named: "es-reports")

        let monthlyCard = app.descendants(matching: .any)["report-card-monthly"].firstMatch
        UITestSupport.scrollToElement(monthlyCard, in: app)
        UITestSupport.tapWhenReady(monthlyCard, timeout: 15)
        XCTAssertTrue(app.navigationBars["Resumen mensual"].waitForExistence(timeout: 15))
        capture(named: "es-monthly-overview")

        launchSeeded(initialTab: "savings")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["Ahorros"], timeout: 15)
        XCTAssertTrue(app.navigationBars["Metas de ahorro"].waitForExistence(timeout: 15))
        capture(named: "es-savings")

        launchSeeded(initialTab: "tax")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["Impuestos"], timeout: 15)
        XCTAssertTrue(app.navigationBars["Estimador fiscal"].waitForExistence(timeout: 15))
        // The demo seed now includes a tax profile, so the seeded launch shows
        // the populated estimator. The empty state is re-covered unseeded below.
        XCTAssertTrue(app.staticTexts["Distribución por tramo"].waitForExistence(timeout: 15))
        capture(named: "es-tax-dashboard")

        let taxProfileButton = app.buttons["tax-profile-button"]
        XCTAssertTrue(taxProfileButton.waitForExistence(timeout: 10))
        XCTAssertTrue(
            taxProfileButton.label.localizedCaseInsensitiveContains("perfil"),
            "Tax profile control must expose a Spanish accessibility label, not only an identifier."
        )
        UITestSupport.tapWhenReady(taxProfileButton, timeout: 10)
        XCTAssertTrue(app.navigationBars["Perfil fiscal"].waitForExistence(timeout: 10))
        // This suite seeds the US demo region (Spanish is for our US market), so
        // the form shows the US filing-status picker — the India regime section
        // is gated on `country == .india` and never appears here. The Hindi
        // suite covers the India path with its own IN seed.
        let filingStatusPicker = app.buttons["Estado, Soltero"]
        XCTAssertTrue(
            filingStatusPicker.waitForExistence(timeout: 10),
            "Tax profile must expose the Spanish filing-status label and value, not only an accessibility id."
        )
        capture(named: "es-tax-profile")

        // Unseeded launch keeps coverage of the Spanish empty state that the
        // demo seed no longer reaches (it now creates a tax profile).
        launchUnseeded(initialTab: "tax")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        UITestSupport.tapWhenReady(app.buttons["Impuestos"], timeout: 15)
        XCTAssertTrue(app.staticTexts["Sin perfil de impuestos"].waitForExistence(timeout: 15))
        capture(named: "es-tax-empty")
        #endif
    }

    @MainActor
    func testCoreFlowsAccessibilityAuditInSpanish() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(initialTab: "dashboard")
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Panel"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transacciones", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        try performCoreFlowAudit()

        UITestSupport.tapWhenReady(app.buttons["transaction-add-button"], timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-form-root"].waitForExistence(timeout: 10)
        )
        try performCoreFlowAudit()
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Presupuestos", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["budget-list-root"].waitForExistence(timeout: 15)
        )
        try performCoreFlowAudit()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Informes", in: app))
        XCTAssertTrue(app.navigationBars["Informes"].waitForExistence(timeout: 15))
        try performCoreFlowAudit()
        #endif
    }

    @MainActor
    func testAccessibility3ScreenshotsInSpanish() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        launchSeeded(
            initialTab: "dashboard",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        )
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Panel"].waitForExistence(timeout: 15))
        capture(named: "es-a11y3-dashboard")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Transacciones", in: app))
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-list-root"].waitForExistence(timeout: 15)
        )
        capture(named: "es-a11y3-transaction-list")

        UITestSupport.tapWhenReady(app.buttons["transaction-add-button"], timeout: 15)
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction-form-root"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.navigationBars["Nueva transacción"].waitForExistence(timeout: 10))
        capture(named: "es-a11y3-add-transaction")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Presupuestos", in: app))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        capture(named: "es-a11y3-budgets")

        XCTAssertTrue(UITestSupport.navigateToTab(named: "Informes", in: app))
        XCTAssertTrue(app.navigationBars["Informes"].waitForExistence(timeout: 15))
        capture(named: "es-a11y3-reports")
        #endif
    }

    @MainActor
    private func launchOnboarding() {
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-onboarding",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_US"
        ]
        app.launchEnvironment["UITEST_FORCE_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    /// Launch in Spanish without the demo seed, for empty-state coverage.
    @MainActor
    private func launchUnseeded(initialTab: String) {
        if app.state != .notRunning {
            app.terminate()
        }
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_US"
        ]
        app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    @MainActor
    private func launchSeeded(initialTab: String, extraArguments: [String] = []) {
        if app.state != .notRunning {
            app.terminate()
        }
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--ui-test-seed-demo",
            "--ui-test-reset-app-lock",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_US"
        ] + extraArguments
        app.launchEnvironment["UITEST_INITIAL_TAB"] = initialTab
        app.launchEnvironment["UITEST_DEMO_REGION"] = "US"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
    }

    @MainActor
    private func performCoreFlowAudit() throws {
        try app.performAccessibilityAudit { issue in
            switch issue.auditType {
            case .hitRegion:
                return true
            case .contrast:
                return true
            case .textClipped:
                let haystack = [
                    issue.compactDescription,
                    issue.detailedDescription,
                    issue.element?.label ?? ""
                ].joined(separator: " ").lowercased()
                if haystack.contains("search") {
                    return true
                }
                return issue.compactDescription.localizedCaseInsensitiveContains("may be clipped")
            case .dynamicType:
                return issue.compactDescription.localizedCaseInsensitiveContains("partially")
            default:
                return false
            }
        }
    }

    @MainActor
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
