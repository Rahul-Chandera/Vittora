import XCTest

/// App Store gallery captures for iPhone (portrait) and iPad (landscape).
///
/// A UI test rather than `simctl` because two things in the gallery need it:
/// iPad landscape (`simctl` has no orientation command; `XCUIDevice.shared
/// .orientation` only exists inside a UI test), and the Household and Tax
/// screens, which are reached by a tap — Tax is an overflow destination that a
/// launch argument can only route to the More hub on iPhone.
///
/// Every navigation uses an accessibility identifier, never a label, so the
/// same code works in en, es and hi.
///
/// Driven by `Scripts/store/capture_screenshots.sh`, which writes the config
/// file this reads. Skipped entirely when that file is absent, so a normal
/// `make test` run never captures anything.
final class StoreGalleryUITests: XCTestCase {

    private struct Config: Decodable {
        let outputDirectory: String
        let locale: String
        let appleLocale: String
        let region: String
        let demoMonths: String
        /// Optional single slot to re-shoot, e.g. "02-transactions". Comes
        /// through the config file rather than the environment because
        /// xcodebuild does not reliably forward shell env to the test runner.
        let only: String?
    }

    private enum Step {
        /// The tab (or deep link) alone is the screen.
        case none
        /// Budgets → Household (M3.4).
        case household
        /// Tax: its own tab on iPad, More → Tax on iPhone.
        case tax
        /// Start the list at a categorised row. The newest two demo rows (a debt
        /// settlement and an emergency-fund transfer) have no category, which
        /// sits badly under a headline about category suggestions.
        case categorisedTransaction
    }

    private struct Shot {
        let name: String
        let tab: String
        var url: String?
        var step: Step = .none
        var extraArguments: [String] = []
    }

    /// The gallery, in upload order. `make_marketing.py` holds a headline per
    /// slot name, so a renamed slot needs its copy renamed too.
    ///
    /// Savings is still not in it: the goal list reads as a plain list in a
    /// still, and 50/30/20 made way for the 1.8.0 reports.
    private static let shots: [Shot] = [
        // The floating add button sits on top of an amount in a still.
        Shot(name: "01-dashboard", tab: "dashboard", extraArguments: ["--ui-test-hide-quick-entry"]),
        // Wide layouts show list + detail; without a selection the detail pane
        // is an empty placeholder taking half the shot.
        Shot(name: "02-transactions", tab: "transactions", step: .categorisedTransaction,
             extraArguments: ["--ui-test-select-first-transaction"]),
        Shot(name: "03-budgets", tab: "budgets"),
        Shot(name: "04-household", tab: "budgets", step: .household, extraArguments: ["--ui-test-seed-household"]),
        Shot(name: "05-tax", tab: "tax", step: .tax),
        Shot(name: "06-healthscore", tab: "reports", url: "vittora://report/healthScore"),
        Shot(name: "07-networth", tab: "reports", url: "vittora://report/netWorth"),
        // Cash Flow Forecast, not Spending Outlook: the outlook's straight-line
        // run-rate turns rent paid on the 1st into a month 7× too high early in
        // the month. Back once that is fixed (1.8.1).
        Shot(name: "08-cashflowforecast", tab: "reports", url: "vittora://report/cashFlowForecast"),
        // Monthly Overview: it carries the month summary (Apple Intelligence where
        // available), which the slot's headline names. Not Reports home, which
        // leads with insight cards that read oddly on the demo data.
        Shot(name: "09-reports", tab: "reports", url: "vittora://report/monthly"),
        Shot(name: "10-yearinreview", tab: "reports", url: "vittora://report/yearInReview"),
    ]

    private static var configURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // VittoraUITests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent(".build/store-shot-config.json")
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @MainActor
    func testCaptureGallery() throws {
        let url = Self.configURL
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("No store-shot config at \(url.path); run capture_screenshots.sh.")
        }
        let config = try JSONDecoder().decode(Config.self, from: data)
        let outDir = URL(fileURLWithPath: config.outputDirectory)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        // One unreachable screen must not cost the rest of the gallery.
        continueAfterFailure = true

        for shot in Self.shots {
            if let only = config.only, !only.isEmpty, only != shot.name { continue }

            let app = XCUIApplication()
            app.launchArguments = [
                "--uitesting",
                "--ui-test-seed-demo",
                "--ui-test-pro",
                "--ui-test-appearance=light",
                "--ui-test-user-name=Alex",
                "-AppleLanguages", "(\(config.locale))",
                "-AppleLocale", config.appleLocale,
            ] + shot.extraArguments
            if let route = shot.url {
                app.launchArguments.append("--ui-test-open-url=\(route)")
            }
            // On iPhone Tax is an overflow destination: launch on the More tab
            // and tap through, since an overflow tab only routes to the hub root.
            let tab = (shot.step == .tax && !isPad) ? "settings" : shot.tab
            app.launchEnvironment["UITEST_INITIAL_TAB"] = tab
            app.launchEnvironment["UITEST_DEMO_REGION"] = config.region
            app.launchEnvironment["UITEST_DEMO_MONTHS"] = config.demoMonths
            app.launch()

            // Rotate after launch: setting it before means the first layout
            // pass happens in portrait and some cards keep the narrow metrics.
            if isPad { XCUIDevice.shared.orientation = .landscapeLeft }
            guard UITestSupport.waitForContentRoot(in: app, timeout: 20) else {
                XCTFail("\(shot.name): content root never appeared, not captured")
                app.terminate()
                continue
            }

            // Seeding is async (a year of history) and report aggregates reload
            // only after it notifies.
            RunLoop.current.run(until: Date().addingTimeInterval(12))

            guard perform(shot.step, in: app, name: shot.name) else {
                app.terminate()
                continue
            }

            let png = XCUIScreen.main.screenshot().pngRepresentation
            try png.write(to: outDir.appendingPathComponent("\(shot.name).png"))
            print("    \(shot.name).png")
            app.terminate()
        }

        XCUIDevice.shared.orientation = .portrait
    }

    /// Returns false (and records a failure) when the screen was not reached,
    /// so a failed navigation is never saved under the slot's name.
    @MainActor
    private func perform(_ step: Step, in app: XCUIApplication, name: String) -> Bool {
        switch step {
        case .none:
            return true
        case .household:
            let button = app.buttons["budget-household-button"]
            guard button.waitForExistence(timeout: 15) else {
                XCTFail("\(name): no Household button")
                return false
            }
            button.tap()
            guard app.descendants(matching: .any)["household-budget-row"].firstMatch
                .waitForExistence(timeout: 15) else {
                XCTFail("\(name): household budgets never appeared")
                return false
            }
        case .categorisedTransaction:
            // Row identifiers are slugs of the demo note, which is English in
            // every locale, so this holds for es and hi too.
            let target = app.descendants(matching: .any)["transaction-row-lunch-order"].firstMatch
            let first = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "transaction-row-")).firstMatch
            guard target.waitForExistence(timeout: 15), first.exists else {
                XCTFail("\(name): transaction rows never appeared")
                return false
            }
            if isPad {
                // Wide layout: select it so the detail pane shows a categorised one.
                target.tap()
            } else {
                // Drag the target row up to where the first row sits, until the
                // first row is under the navigation bar. The first drag mostly
                // collapses the large title, hence the loop. A short press, well
                // under the rows' long-press (multi-select) threshold, and a slow
                // drag so it does not fling past.
                let firstRow = app.descendants(matching: .any)[first.identifier].firstMatch
                for _ in 0..<4 {
                    let barBottom = app.navigationBars.firstMatch.frame.maxY
                    if !firstRow.exists || firstRow.frame.maxY <= barBottom + 4 { break }
                    let from = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    let to = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.5)
                }
            }
        case .tax:
            if !isPad {
                let row = app.buttons["more-tax-row"].firstMatch
                UITestSupport.scrollToElement(row, in: app)
                guard row.waitForExistence(timeout: 15) else {
                    XCTFail("\(name): no Tax row in More")
                    return false
                }
                row.tap()
            }
            guard app.buttons["tax-profile-button"].waitForExistence(timeout: 15) else {
                XCTFail("\(name): tax dashboard never appeared")
                return false
            }
        }
        // Let the pushed screen finish loading and animating.
        RunLoop.current.run(until: Date().addingTimeInterval(4))
        return true
    }
}
