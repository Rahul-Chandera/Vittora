import Foundation
import SwiftUI
import Testing
@testable import Vittora

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {

    private func makeViewModel(keychainService: MockKeychainService) -> SettingsViewModel {
        SettingsViewModel(keychainService: keychainService)
    }

    // MARK: - Static data

    @Test("supportedCurrencies is non-empty")
    func supportedCurrenciesNonEmpty() {
        let vm = makeViewModel(keychainService: MockKeychainService())
        #expect(!vm.supportedCurrencies.isEmpty)
    }

    @Test("supportedCurrencies contains USD and INR")
    func supportedCurrenciesContainsMainCodes() {
        let vm = makeViewModel(keychainService: MockKeychainService())
        let codes = vm.supportedCurrencies.map(\.code)
        #expect(codes.contains("USD"))
        #expect(codes.contains("INR"))
    }

    @Test("appVersion is non-empty")
    func appVersionNonEmpty() {
        let vm = makeViewModel(keychainService: MockKeychainService())
        #expect(!vm.appVersion.isEmpty)
    }

    @Test("buildNumber is non-empty")
    func buildNumberNonEmpty() {
        let vm = makeViewModel(keychainService: MockKeychainService())
        #expect(!vm.buildNumber.isEmpty)
    }

    // MARK: - AppearanceMode

    @Test("AppearanceMode.system has nil colorScheme")
    func appearanceModeSystemNilScheme() {
        #expect(SettingsViewModel.AppearanceMode.system.colorScheme == nil)
    }

    @Test("AppearanceMode.light has .light colorScheme")
    func appearanceModeLightScheme() {
        #expect(SettingsViewModel.AppearanceMode.light.colorScheme == .light)
    }

    @Test("AppearanceMode.dark has .dark colorScheme")
    func appearanceModeDarkScheme() {
        #expect(SettingsViewModel.AppearanceMode.dark.colorScheme == .dark)
    }

    @Test("AppearanceMode has 3 cases")
    func appearanceModeThreeCases() {
        #expect(SettingsViewModel.AppearanceMode.allCases.count == 3)
    }

    // MARK: - ExportSchedule

    @Test("ExportSchedule has 3 cases")
    func exportScheduleThreeCases() {
        #expect(SettingsViewModel.ExportSchedule.allCases.count == 3)
    }

    @Test("ExportSchedule.off displayName is non-empty")
    func exportScheduleOffDisplayName() {
        #expect(!SettingsViewModel.ExportSchedule.off.displayName.isEmpty)
    }

    // MARK: - Keychain-backed properties

    @Test("setting isAppLockEnabled true schedules Keychain save")
    func setIsAppLockEnabledTrue() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        vm.isAppLockEnabled = true

        // Allow the async Task inside isAppLockEnabled setter to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        let savedData = try await keychain.load(forKey: "vittora.appLockEnabled", access: .standard)
        #expect(savedData?.first == 1)
    }

    @Test("setting isAppLockEnabled false schedules Keychain save as 0")
    func setIsAppLockEnabledFalse() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        vm.isAppLockEnabled = false

        try await Task.sleep(nanoseconds: 50_000_000)

        let savedData = try await keychain.load(forKey: "vittora.appLockEnabled", access: .standard)
        #expect(savedData?.first == 0)
    }

    @Test("setting userName non-empty schedules Keychain save")
    func setUserNameNonEmpty() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        vm.userName = "Alice"

        try await Task.sleep(nanoseconds: 50_000_000)

        let savedData = try await keychain.load(forKey: "vittora.userName", access: .standard)
        let savedName = savedData.flatMap { String(data: $0, encoding: .utf8) }
        #expect(savedName == "Alice")
    }

    @Test("Keychain error sets keychainError property")
    func keychainErrorSetsProperty() async throws {
        let keychain = MockKeychainService()
        keychain.shouldThrowError = true
        let vm = makeViewModel(keychainService: keychain)

        vm.isAppLockEnabled = true

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.keychainError != nil)
    }
}
