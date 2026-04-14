import Foundation
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case currency
        case profile
        case done

        var isLast: Bool { self == .done }
    }

    var currentStep: Step = .welcome
    var selectedCurrencyCode = "USD"
    var userName = ""
    var isSaving = false

    var canAdvance: Bool {
        switch currentStep {
        case .welcome:   return true
        case .currency:  return !selectedCurrencyCode.isEmpty
        case .profile:   return true   // name is optional
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

    func complete(appState: AppState) {
        // Persist selections
        UserDefaults.standard.set(selectedCurrencyCode, forKey: "vittora.currencyCode")
        if !userName.isEmpty {
            UserDefaults.standard.set(userName, forKey: "vittora.userName")
        }
        UserDefaults.standard.set(true, forKey: "vittora.onboardingComplete")
        appState.isOnboardingComplete = true
    }
}
