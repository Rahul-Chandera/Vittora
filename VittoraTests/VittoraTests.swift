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

    @Test("AppTab has titles and icons")
    func appTabProperties() {
        for tab in AppState.AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.systemImage.isEmpty)
            #expect(!tab.id.isEmpty)
        }
    }
}
