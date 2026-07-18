import Foundation
import SwiftUI
import Testing
import VittoraCore
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

    @Test("appearanceMode change notifies observers (theme actually switches)")
    func appearanceModeIsObservable() {
        final class Flag: @unchecked Sendable { var value = false }
        let flag = Flag()

        let vm = makeViewModel(keychainService: MockKeychainService())
        vm.appearanceMode = .light

        withObservationTracking {
            _ = vm.appearanceMode
        } onChange: {
            flag.value = true
        }

        vm.appearanceMode = .dark
        // Fails if the UserDefaults-backed property lacks access/withMutation,
        // which is why the theme never changed off Light.
        #expect(flag.value)
    }

    @Test("reloadPersistedProfile republishes currency so the UI refreshes")
    func reloadPersistedProfileNotifiesCurrency() {
        final class Flag: @unchecked Sendable { var value = false }
        let flag = Flag()

        let vm = makeViewModel(keychainService: MockKeychainService())
        withObservationTracking {
            _ = vm.selectedCurrencyCode
        } onChange: {
            flag.value = true
        }

        // Onboarding writes the currency straight to UserDefaults; reload must
        // notify observers so .environment(\.currencyCode) re-reads it.
        vm.reloadPersistedProfile()
        #expect(flag.value)
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

    @Test("updateAppLockEnabled true persists to Keychain")
    func setIsAppLockEnabledTrue() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        await vm.updateAppLockEnabled(true)

        let savedData = try await keychain.load(forKey: AppUserDefaults.KeychainKey.appLockEnabled, access: .standard)
        #expect(savedData?.first == 1)
        #expect(vm.isAppLockEnabled == true)
    }

    @Test("updateAppLockEnabled false persists to Keychain as 0")
    func setIsAppLockEnabledFalse() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        await vm.updateAppLockEnabled(true)
        await vm.updateAppLockEnabled(false)

        let savedData = try await keychain.load(forKey: AppUserDefaults.KeychainKey.appLockEnabled, access: .standard)
        #expect(savedData?.first == 0)
        #expect(vm.isAppLockEnabled == false)
    }

    @Test("updateUserName persists non-empty value to Keychain")
    func setUserNameNonEmpty() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        await vm.updateUserName("Alice")

        let savedData = try await keychain.load(forKey: AppUserDefaults.KeychainKey.userName, access: .standard)
        let savedName = savedData.flatMap { String(data: $0, encoding: .utf8) }
        #expect(savedName == "Alice")
        #expect(vm.userName == "Alice")
    }

    @Test("Keychain error reverts app lock state and sets keychainError")
    func keychainErrorRevertsAppLockState() async throws {
        let keychain = MockKeychainService()
        let vm = makeViewModel(keychainService: keychain)

        // Init may hydrate from the real keychain; normalize through the mock first
        // so a parallel suite cannot leave previous=true and mask the revert.
        await vm.updateAppLockEnabled(false)
        #expect(vm.isAppLockEnabled == false)

        keychain.shouldThrowError = true
        await vm.updateAppLockEnabled(true)

        #expect(vm.isAppLockEnabled == false)
        #expect(vm.keychainError != nil)
    }

    @Test("appLockTimeout defaults to five minutes")
    func appLockTimeoutDefault() {
        UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockTimeout)
        let vm = makeViewModel(keychainService: MockKeychainService())
        #expect(vm.appLockTimeout == AppLockTimeout.fiveMinutes)
    }

    @Test("appLockTimeout persists to UserDefaults")
    func appLockTimeoutPersists() {
        defer { UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockTimeout) }
        let vm = makeViewModel(keychainService: MockKeychainService())
        vm.appLockTimeout = AppLockTimeout.oneMinute
        #expect(vm.appLockTimeout == AppLockTimeout.oneMinute)
        #expect(
            UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appLockTimeout)
                == AppLockTimeout.oneMinute.rawValue
        )
    }

    @Test("disableAppLockIfAuthenticated aborts when user cancels")
    func disableAppLockCancelled() async throws {
        let vm = makeViewModel(keychainService: MockKeychainService())
        await vm.updateAppLockEnabled(true)
        #expect(vm.isAppLockEnabled == true)

        let biometric = MockBiometricService()
        biometric.shouldSucceed = false
        let disabled = await vm.disableAppLockIfAuthenticated(using: biometric)

        #expect(disabled == false)
        #expect(vm.isAppLockEnabled == true)
    }

    @Test("disableAppLockIfAuthenticated disables when user authenticates")
    func disableAppLockSuccess() async throws {
        let vm = makeViewModel(keychainService: MockKeychainService())
        await vm.updateAppLockEnabled(true)
        #expect(vm.isAppLockEnabled == true)

        let biometric = MockBiometricService()
        biometric.shouldSucceed = true
        let disabled = await vm.disableAppLockIfAuthenticated(using: biometric)

        #expect(disabled == true)
        #expect(vm.isAppLockEnabled == false)
    }
}
