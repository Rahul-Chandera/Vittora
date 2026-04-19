//
//  VittoraTests.swift
//  VittoraTests
//
//  Created by Rahul on 12/04/26.
//

import Testing
@testable import Vittora

@Suite("Vittora Foundation Tests")
struct VittoraTests {
    @Test("AppState initializes with default values")
    @MainActor
    func appStateDefaults() {
        let state = AppState(isOnboardingComplete: false)
        #expect(state.isAuthenticated == false)
        #expect(state.isOnboardingComplete == false)
        #expect(state.selectedTab == .dashboard)
        #expect(state.isLoading == false)
    }

    @Test("AppTab has correct count")
    func appTabCount() {
        #expect(AppState.AppTab.allCases.count == 9)
    }

    @Test("AppTab titles match expected localized strings")
    func appTabTitles() {
        #expect(AppState.AppTab.dashboard.title    == String(localized: "Dashboard"))
        #expect(AppState.AppTab.transactions.title == String(localized: "Transactions"))
        #expect(AppState.AppTab.budgets.title      == String(localized: "Budgets"))
        #expect(AppState.AppTab.reports.title      == String(localized: "Reports"))
        #expect(AppState.AppTab.debt.title         == String(localized: "Debt"))
        #expect(AppState.AppTab.splits.title       == String(localized: "Splits"))
        #expect(AppState.AppTab.tax.title          == String(localized: "Tax"))
        #expect(AppState.AppTab.savings.title      == String(localized: "Savings"))
        #expect(AppState.AppTab.settings.title     == String(localized: "Settings"))
    }

    @Test("AppTab system images match expected SF Symbol names")
    func appTabSystemImages() {
        #expect(AppState.AppTab.dashboard.systemImage    == "chart.pie.fill")
        #expect(AppState.AppTab.transactions.systemImage == "list.bullet.rectangle.fill")
        #expect(AppState.AppTab.budgets.systemImage      == "target")
        #expect(AppState.AppTab.reports.systemImage      == "chart.bar.fill")
        #expect(AppState.AppTab.debt.systemImage         == "hand.point.up.left.fill")
        #expect(AppState.AppTab.splits.systemImage       == "person.3.fill")
        #expect(AppState.AppTab.tax.systemImage          == "building.columns.fill")
        #expect(AppState.AppTab.savings.systemImage      == "star.circle.fill")
        #expect(AppState.AppTab.settings.systemImage     == "gearshape.fill")
    }

    @Test("AppTab id equals rawValue")
    func appTabIDEqualsRawValue() {
        for tab in AppState.AppTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }
}
