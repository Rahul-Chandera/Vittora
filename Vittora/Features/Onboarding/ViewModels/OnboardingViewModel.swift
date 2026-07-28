import Foundation
import SwiftUI
import VittoraCore

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case currency
        case profile
        case account
        case notifications
        case done

        var isLast: Bool { self == .done }
    }

    enum AccountSubStep { case type, details }

    var currentStep: Step = .welcome
    var accountSubStep: AccountSubStep = .type
    var isAccountSubStepEnabled: Bool = false
    var selectedCurrencyCode = CurrencyDefaults.code
    var userName = ""
    var accountName = ""
    var selectedAccountType: AccountType = .bank
    var openingBalance = ""
    var wantsNotifications = false
    var isSaving = false
    var error: String?

    private let createAccountUseCase: CreateAccountUseCase?
    private let keychainService: any KeychainServiceProtocol
    private let userDefaults: UserDefaults

    init(
        createAccountUseCase: CreateAccountUseCase? = nil,
        keychainService: (any KeychainServiceProtocol)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.createAccountUseCase = createAccountUseCase
        self.keychainService = keychainService ?? KeychainService()
        self.userDefaults = userDefaults
    }

    var canAdvance: Bool {
        switch currentStep {
        case .welcome:   return true
        case .currency:  return !selectedCurrencyCode.isEmpty
        case .profile:   return hasValidProfileName
        case .account:
            return (isAccountSubStepEnabled && accountSubStep == .type) ? true : hasValidAccountSetup
        case .notifications:
            return true
        case .done:      return hasValidAccountSetup
        }
    }

    let supportedCurrencies: [(code: String, flag: String, name: String)] = [
        ("USD", "🇺🇸", "US Dollar"),
        ("INR", "🇮🇳", "Indian Rupee"),
        ("EUR", "🇪🇺", "Euro"),
        ("GBP", "🇬🇧", "British Pound"),
        ("JPY", "🇯🇵", "Japanese Yen"),
        ("CAD", "🇨🇦", "Canadian Dollar"),
        ("AUD", "🇦🇺", "Australian Dollar"),
        ("SGD", "🇸🇬", "Singapore Dollar"),
        ("AED", "🇦🇪", "UAE Dirham"),
    ]

    func advance() {
        if currentStep == .account && accountSubStep == .type && isAccountSubStepEnabled {
            accountSubStep = .details
            return
        }
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func complete(appState: AppState) async {
        guard !isSaving else { return }
        guard hasValidAccountSetup else {
            error = String(localized: "Complete your first account setup to continue.")
            return
        }

        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            if let createAccountUseCase, let openingBalance = normalizedOpeningBalance {
                do {
                    try await createAccountUseCase.execute(
                        name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: selectedAccountType,
                        balance: openingBalance,
                        currencyCode: selectedCurrencyCode,
                        icon: selectedAccountType.onboardingIconName
                    )
                } catch VittoraError.duplicateEntry {
                    // The account already exists — CloudKit restored the user's
                    // data into the fresh store mid-onboarding, or a previous
                    // completion attempt got this far before failing. Either
                    // way completion is idempotent: keep the existing account.
                }
            }

            // currencyCode is non-sensitive; UserDefaults is acceptable
            userDefaults.set(selectedCurrencyCode, forKey: AppUserDefaults.StandardKey.currencyCode)
            AppUserDefaults.mirrorCurrencyCodeToAppGroup()

            persistNotificationPreference()

            let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                try await keychainService.delete(forKey: AppUserDefaults.KeychainKey.userName)
            } else if let data = trimmedName.data(using: .utf8) {
                try await keychainService.save(data, forKey: AppUserDefaults.KeychainKey.userName)
            }

            try await keychainService.save(Data([1]), forKey: AppUserDefaults.KeychainKey.onboardingComplete)
            appState.isOnboardingComplete = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var normalizedOpeningBalance: Decimal? {
        Decimal(localizedAmount: openingBalance)
    }

    private var hasValidAccountSetup: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedOpeningBalance != nil
    }

    private var hasValidProfileName: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Records notification intent only — the OS permission prompt is deferred to Settings (C6).
    private func persistNotificationPreference() {
        userDefaults.set(wantsNotifications, forKey: AppUserDefaults.StandardKey.notificationsEnabled)
    }
}

private extension AccountType {
    var onboardingIconName: String {
        switch self {
        case .cash:          "banknote.fill"
        case .bank:          "building.columns.fill"
        case .creditCard:    "creditcard.fill"
        case .loan:          "arrow.up.arrow.down.circle.fill"
        case .digitalWallet: "iphone.gen2"
        case .investment:    "chart.line.uptrend.xyaxis"
        case .receivable:    "arrow.down.circle.fill"
        case .payable:       "arrow.up.circle.fill"
        }
    }
}
