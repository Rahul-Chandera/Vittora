import Foundation
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case currency
        case profile
        case account
        case done

        var isLast: Bool { self == .done }
    }

    var currentStep: Step = .welcome
    var selectedCurrencyCode = CurrencyDefaults.code
    var userName = ""
    var accountName = ""
    var selectedAccountType: AccountType = .bank
    var openingBalance = "0"
    var isSaving = false
    var error: String?

    private let createAccountUseCase: CreateAccountUseCase?
    private let keychainService: any KeychainServiceProtocol

    init(
        createAccountUseCase: CreateAccountUseCase? = nil,
        keychainService: (any KeychainServiceProtocol)? = nil
    ) {
        self.createAccountUseCase = createAccountUseCase
        self.keychainService = keychainService ?? KeychainService()
    }

    var canAdvance: Bool {
        switch currentStep {
        case .welcome:   return true
        case .currency:  return !selectedCurrencyCode.isEmpty
        case .profile:   return true   // name is optional
        case .account:
            return !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            normalizedOpeningBalance != nil
        case .done:      return true
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
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }

    func complete(appState: AppState) async {
        guard !isSaving else { return }
        guard canAdvance else {
            error = String(localized: "Complete your first account setup to continue.")
            return
        }

        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            if let createAccountUseCase, let openingBalance = normalizedOpeningBalance {
                try await createAccountUseCase.execute(
                    name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedAccountType,
                    balance: openingBalance,
                    currencyCode: selectedCurrencyCode,
                    icon: selectedAccountType.onboardingIconName
                )
            }

            // currencyCode is non-sensitive; UserDefaults is acceptable
            UserDefaults.standard.set(selectedCurrencyCode, forKey: "vittora.currencyCode")

            let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                try await keychainService.delete(forKey: "vittora.userName")
            } else if let data = trimmedName.data(using: .utf8) {
                try await keychainService.save(data, forKey: "vittora.userName")
            }

            try await keychainService.save(Data([1]), forKey: "vittora.onboardingComplete")
            appState.isOnboardingComplete = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var normalizedOpeningBalance: Decimal? {
        let trimmed = openingBalance.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        return Decimal(string: sanitized)
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
