import XCTest

/// Landscape iPad captures for the App Store gallery.
///
/// Everything else in the gallery pipeline is driven by `simctl` from
/// `Scripts/store/capture_screenshots.sh`, which is simpler and has no build
/// dependency. iPad landscape cannot go that route: `simctl` has no orientation
/// command, and rotating Simulator.app through AppleScript needs the GUI
/// frontmost plus accessibility permissions. `XCUIDevice.shared.orientation` is
/// the only reliable handle, and that only exists inside a UI test.
///
/// Driven by `Scripts/store/capture_ipad_landscape.sh`, which writes the config
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

    /// Same six slots, in the same order, as the `SHOTS` array in
    /// `capture_screenshots.sh` — including the note that Savings is not
    /// capturable because overflow tabs route to the More hub root.
    private static let shots: [(tab: String, url: String?, name: String)] = [
        ("dashboard", nil, "01-dashboard"),
        ("transactions", nil, "02-transactions"),
        ("budgets", nil, "03-budgets"),
        ("reports", "vittora://report/fiftyThirtyTwenty", "04-fiftythirtytwenty"),
        ("reports", nil, "05-reports"),
        ("reports", "vittora://report/yearInReview", "06-yearinreview"),
    ]

    private static var configURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // VittoraUITests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent(".build/store-shot-config.json")
    }

    @MainActor
    func testCaptureLandscapeGallery() throws {
        let url = Self.configURL
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("No store-shot config at \(url.path); run capture_ipad_landscape.sh.")
        }
        let config = try JSONDecoder().decode(Config.self, from: data)
        let outDir = URL(fileURLWithPath: config.outputDirectory)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for shot in Self.shots {
            if let only = config.only, !only.isEmpty, only != shot.name {
                continue
            }
            let app = XCUIApplication()
            app.launchArguments = [
                "--uitesting",
                "--ui-test-seed-demo",
                "--ui-test-appearance=light",
                "-AppleLanguages", "(\(config.locale))",
                "-AppleLocale", config.appleLocale,
            ]
            if let route = shot.url {
                app.launchArguments.append("--ui-test-open-url=\(route)")
            }
            if shot.name == "02-transactions" {
                // Wide layouts show list + detail; without a selection the
                // detail pane is an empty placeholder taking half the shot.
                app.launchArguments.append("--ui-test-select-first-transaction")
            }
            app.launchEnvironment["UITEST_INITIAL_TAB"] = shot.tab
            app.launchEnvironment["UITEST_DEMO_REGION"] = config.region
            app.launchEnvironment["UITEST_DEMO_MONTHS"] = config.demoMonths
            app.launch()

            // Rotate after launch: setting it before means the first layout
            // pass happens in portrait and some cards keep the narrow metrics.
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(UITestSupport.waitForContentRoot(in: app),
                          "\(shot.name): content root never appeared")

            // Seeding is async (a year of history) and report aggregates reload
            // only after it notifies — same reason the shell script sleeps 12.
            RunLoop.current.run(until: Date().addingTimeInterval(12))

            let png = XCUIScreen.main.screenshot().pngRepresentation
            try png.write(to: outDir.appendingPathComponent("\(shot.name).png"))
            print("    \(shot.name).png")

            app.terminate()
        }

        XCUIDevice.shared.orientation = .portrait
    }
}
