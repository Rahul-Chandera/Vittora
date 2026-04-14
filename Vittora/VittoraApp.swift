//
//  VittoraApp.swift
//  Vittora
//
//  Created by Rahul on 12/04/26.
//

import SwiftUI
import SwiftData

@main
struct VittoraApp: App {
    @State private var appState = AppState()
    @State private var router = Router()
    @State private var dependencies: DependencyContainer
    @State private var settingsVM = SettingsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerConfig.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        _dependencies = State(initialValue: DependencyContainer.createDefault(modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(router)
                .environment(\.dependencies, dependencies)
                .environment(settingsVM)
                .preferredColorScheme(settingsVM.appearanceMode.colorScheme)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && settingsVM.isAppLockEnabled {
                appState.isLocked = true
                appState.isAuthenticated = false
            }
        }
    }
}
