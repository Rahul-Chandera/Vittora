import Foundation
import Testing
@testable import Vittora

/// Which way the macOS detail pane slides when the sidebar selection changes.
///
/// The ordering is the part that can silently go wrong: `AppTab` declares
/// reports/debt/splits BEFORE tax/savings, while the sidebar shows savings
/// before reports. Using the enum's order would animate Savings -> Reports
/// backwards even though the user moved down the list.
///
/// These run on iOS too, deliberately — `SidebarOrder` is kept out of
/// `#if os(macOS)` precisely so CI, which only runs the iOS suite, can cover
/// it. A macOS-gated test here would never execute.
@Suite("Sidebar order and slide direction")
struct SidebarOrderTests {

    @Test("moving down the sidebar pushes forward")
    func downwardIsForward() {
        #expect(SidebarOrder.movesDown(from: .dashboard, to: .transactions))
        #expect(SidebarOrder.movesDown(from: .savings, to: .reports))
        #expect(SidebarOrder.movesDown(from: .splits, to: .settings))
    }

    @Test("moving up the sidebar pops backward")
    func upwardIsBackward() {
        #expect(!SidebarOrder.movesDown(from: .transactions, to: .dashboard))
        #expect(!SidebarOrder.movesDown(from: .reports, to: .savings))
        #expect(!SidebarOrder.movesDown(from: .settings, to: .dashboard))
    }

    /// The case the enum's own order gets wrong, which is the whole reason
    /// this type exists.
    @Test("direction follows the sidebar's visual order, not the enum's")
    func visualOrderNotDeclarationOrder() {
        let declaration = AppState.AppTab.allCases
        let savingsFirstVisually =
            SidebarOrder.tabs.firstIndex(of: .savings)! < SidebarOrder.tabs.firstIndex(of: .reports)!
        let savingsFirstInEnum =
            declaration.firstIndex(of: .savings)! < declaration.firstIndex(of: .reports)!

        #expect(savingsFirstVisually)
        #expect(!savingsFirstInEnum, "enum reordered — this test has lost its point, revisit it")
        #expect(SidebarOrder.movesDown(from: .savings, to: .reports))
    }

    /// A tab missing here silently falls back to index 0 and animates wrongly.
    @Test("every tab appears exactly once")
    func orderCoversEveryTabOnce() {
        #expect(Set(SidebarOrder.tabs).count == SidebarOrder.tabs.count)
        #expect(Set(SidebarOrder.tabs) == Set(AppState.AppTab.allCases))
    }
}
