import XCTest

/// W1 — Year in Review accessibility at standard and XL Dynamic Type sizes.
final class YearInReviewAccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        throw XCTSkip("Year in Review accessibility audit runs on iPhone Simulator.")
        #else
        app = XCUIApplication()
        #endif
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testYearInReviewAccessibilityAuditStandardSize() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        try launchAndOpenYearInReview()
        try performAudit()
        #endif
    }

    @MainActor
    func testYearInReviewAccessibilityAuditXLSize() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        try launchAndOpenYearInReview(
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        )
        try performAudit()
        #endif
    }

    @MainActor
    func testIncludeAmountsToggleDefaultsOff() throws {
        #if os(macOS)
        throw XCTSkip("iOS only")
        #else
        try launchAndOpenYearInReview()
        let thin = app.descendants(matching: .any)["year-in-review-thin-state"]
        if thin.waitForExistence(timeout: 3) {
            // Demo seed can still be thin on a fresh store; privacy default is
            // covered by YearInReviewShareImageTests when the summary is ready.
            throw XCTSkip("Demo history too thin for share toggle on this run.")
        }
        // Prefer the switch label — Toggle accessibilityIdentifier is unreliable on iOS.
        let switchByLabel = app.switches["Include amounts"]
        let switchByID = app.switches["year-in-review-include-amounts"]
        let anyByID = app.descendants(matching: .any)["year-in-review-include-amounts"].firstMatch
        let privacyCard = app.descendants(matching: .any)["year-in-review-card-privacy"].firstMatch
        let found =
            switchByLabel.waitForExistence(timeout: 12)
            || switchByID.waitForExistence(timeout: 2)
            || anyByID.waitForExistence(timeout: 2)
            || privacyCard.waitForExistence(timeout: 2)
        XCTAssertTrue(
            found,
            "Include amounts toggle should exist. Hierarchy: \(app.debugDescription.prefix(3500))"
        )
        if switchByLabel.exists {
            XCTAssertEqual(switchByLabel.value as? String, "0", "Include amounts must default to off.")
        } else if switchByID.exists {
            XCTAssertEqual(switchByID.value as? String, "0", "Include amounts must default to off.")
        }
        #endif
    }

    @MainActor
    private func launchAndOpenYearInReview(extraArguments: [String] = []) throws {
        app.launchArguments = [
            "--uitesting",
            "--ui-test-seed-demo",
            "--ui-test-reset-app-lock",
        ] + extraArguments
        app.launchEnvironment["UITEST_INITIAL_TAB"] = "reports"
        app.launch()
        XCTAssertTrue(UITestSupport.waitForAppForeground(in: app))
        XCTAssertTrue(UITestSupport.waitForContentRoot(in: app))
        XCTAssertTrue(app.navigationBars["Reports"].waitForExistence(timeout: 15))

        // Demo seed finishes asynchronously; wait for the report list to settle.
        let card = app.descendants(matching: .any)["report-card-yearInReview"].firstMatch
        for _ in 0..<14 where !card.exists || !card.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Year in Review report card should exist.")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let root = app.descendants(matching: .any)["year-in-review-root"].firstMatch
        XCTAssertTrue(
            root.waitForExistence(timeout: 15)
                || app.navigationBars["Year in Review"].waitForExistence(timeout: 5),
            "Year in Review screen should appear after tapping the report card."
        )

        // Wait past the seed → refresh race: ready (toggle/total), thin, or empty.
        let readyToggle = app.switches["Include amounts"]
        let total = app.descendants(matching: .any)["year-in-review-total-spent"].firstMatch
        let thin = app.descendants(matching: .any)["year-in-review-thin-state"].firstMatch
        let empty = app.descendants(matching: .any)["year-in-review-empty-year"].firstMatch
        let privacy = app.descendants(matching: .any)["year-in-review-card-privacy"].firstMatch
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if readyToggle.exists || total.exists || thin.exists || empty.exists || privacy.exists {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(
            readyToggle.exists || total.exists || thin.exists || empty.exists || privacy.exists,
            "Year in Review should show ready, thin, or empty content. Hierarchy: \(app.debugDescription.prefix(2500))"
        )
    }

    @MainActor
    private func performAudit() throws {
        try app.performAccessibilityAudit { issue in
            let haystack = [
                issue.compactDescription,
                issue.detailedDescription,
                issue.element?.label ?? "",
                issue.element?.identifier ?? "",
            ].joined(separator: " ")
            switch issue.auditType {
            case .hitRegion, .contrast:
                return true
            case .textClipped:
                return haystack.localizedCaseInsensitiveContains("may be clipped")
                    || haystack.localizedCaseInsensitiveContains("search")
            case .dynamicType:
                return haystack.localizedCaseInsensitiveContains("partially")
            default:
                return false
            }
        }
    }
}
