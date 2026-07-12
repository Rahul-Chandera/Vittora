import SwiftUI
import VittoraCore
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var vm: OnboardingViewModel

    init(createAccountUseCase: CreateAccountUseCase? = nil) {
        _vm = State(initialValue: OnboardingViewModel(createAccountUseCase: createAccountUseCase))
    }

    var body: some View {
        ZStack {
            VColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                if vm.currentStep != .done {
                    progressDots
                        .padding(.top, VSpacing.xl)
                }

                // Step content. Deliberately NOT a paging TabView: the pager
                // keeps neighboring pages (each with text fields → its own
                // keyboard host) alive at once, which broke keyboard layout on
                // iPad and let it write a wrong page back mid-animation,
                // skipping the account step. Swiping would also bypass the
                // canAdvance validation gating. One step view at a time.
                Group {
                    switch vm.currentStep {
                    case .welcome:       WelcomeStepView()
                    case .currency:      CurrencyStepView(vm: vm)
                    case .profile:       ProfileStepView(vm: vm)
                    case .account:       AccountSetupStepView(vm: vm)
                    case .notifications: NotificationsStepView(vm: vm)
                    case .done:          DoneStepView(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(vm.currentStep)
                .animation(reduceMotion ? .none : .easeInOut, value: vm.currentStep)

                // CTA button
                ctaButton
                    .padding(.horizontal, VSpacing.screenPadding)
                    .padding(.bottom, VSpacing.xxxl)
            }
        }
        .alert(String(localized: "Error"), isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button(String(localized: "OK")) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-root")
        .onChange(of: vm.currentStep) { _, _ in
            // The step views own their FocusStates; when the CTA advances the
            // step, nothing clears them and the keyboard stays up over the next
            // step. Resign globally on every step change.
            dismissKeyboard()
        }
        #if os(iOS)
        .onChange(of: horizontalSizeClass, initial: true) { _, new in
            vm.isAccountSubStepEnabled = new == .compact
            if new != .compact { vm.accountSubStep = .type }
        }
        #endif
    }

    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        #endif
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.Step.allCases.filter { $0 != .done }, id: \.rawValue) { step in
                Capsule()
                    .fill(vm.currentStep.rawValue >= step.rawValue ? VColors.primary : VColors.primary.opacity(0.2))
                    .frame(width: vm.currentStep == step ? 24 : 8, height: 8)
                    .animation(reduceMotion ? .none : .spring(duration: 0.3), value: vm.currentStep)
            }
        }
        .padding(.bottom, VSpacing.lg)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            if vm.currentStep == .done {
                Task {
                    await vm.complete(appState: appState)
                }
            } else {
                vm.advance()
            }
        } label: {
            HStack {
                if vm.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(buttonTitle)
                    .font(VTypography.bodyBold)
                if vm.currentStep != .done && !vm.isSaving {
                    Image(systemName: "arrow.right")
                        .font(.body.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(VSpacing.md)
            .background(VColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD))
            .opacity((vm.canAdvance && !vm.isSaving) ? 1 : 0.55)
        }
        .disabled(!vm.canAdvance || vm.isSaving)
        .accessibilityIdentifier("onboarding-next-button")
    }

    private var buttonTitle: String {
        switch vm.currentStep {
        case .welcome:  return String(localized: "Get Started")
        case .currency: return String(localized: "Continue")
        case .profile:  return String(localized: "Set Up Account")
        case .account:  return (vm.isAccountSubStepEnabled && vm.accountSubStep == .type)
                            ? String(localized: "Continue")
                            : String(localized: "Review Setup")
        case .notifications:
            return String(localized: "Continue")
        case .done:     return String(localized: "Start Tracking")
        }
    }

}

// MARK: - Step Views

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Image("OnboardingAppLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "Welcome to Vittora"))
                    .font(VTypography.title1.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding-welcome-title")

                Text(String(localized: "Your all-in-one personal finance companion for tracking money, budgets, goals, taxes and more."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            VStack(alignment: .leading, spacing: VSpacing.md) {
                FeatureRow(icon: "chart.pie.fill",   color: .purple, text: String(localized: "Track income & expenses"))
                FeatureRow(icon: "target",            color: .orange, text: String(localized: "Set and manage budgets"))
                FeatureRow(icon: "star.circle.fill",  color: .yellow, text: String(localized: "Save towards your goals"))
                FeatureRow(icon: "person.2.fill",     color: .blue,   text: String(localized: "Split expenses with friends"))
                FeatureRow(icon: "building.columns",  color: .green,  text: String(localized: "Estimate your taxes"))
            }
            .padding(.horizontal, VSpacing.xl)

            Spacer()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(VTypography.body)
                .foregroundStyle(VColors.textPrimary)
        }
    }
}

private struct CurrencyStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VColors.primary)
                    .frame(width: 76, height: 76)
                Text(selectedCurrencySymbol)
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "Choose Your Currency"))
                    .font(VTypography.title2.bold())
                    .foregroundStyle(VColors.textPrimary)
                Text(String(localized: "This will be your default display currency."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.supportedCurrencies, id: \.code) { currency in
                        Button {
                            vm.selectedCurrencyCode = currency.code
                        } label: {
                            HStack(spacing: VSpacing.md) {
                                Text(currency.flag)
                                    .font(.title2)
                                Text(currency.name)
                                    .font(VTypography.body)
                                    .foregroundStyle(VColors.textPrimary)
                                Spacer()
                                Text(currency.code)
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.textSecondary)
                                if vm.selectedCurrencyCode == currency.code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(VColors.primary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(VSpacing.md)
                            .background(vm.selectedCurrencyCode == currency.code
                                        ? VColors.primary.opacity(0.08) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(currency.name), \(currency.code)")
                        .accessibilityAddTraits(vm.selectedCurrencyCode == currency.code ? .isSelected : [])
                        .accessibilityIdentifier("onboarding-currency-\(currency.code)")
                        Divider()
                    }
                }
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
                .padding(.horizontal, VSpacing.screenPadding)
            }

            Spacer()
        }
    }

    private var selectedCurrencySymbol: String {
        CurrencyDefaults.symbol(for: vm.selectedCurrencyCode)
    }
}

private struct ProfileStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(VColors.primary)

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "What should we call you?"))
                    .font(VTypography.title2.bold())
                    .foregroundStyle(VColors.textPrimary)
                Text(String(localized: "Enter your name. You can change this in settings anytime."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            TextField(String(localized: "Your name"), text: $vm.userName)
                .font(VTypography.title3)
                .multilineTextAlignment(.center)
                #if os(iOS)
                .textContentType(.name)
                #endif
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusMD)
                .padding(.horizontal, VSpacing.xl)
                .accessibilityIdentifier("onboarding-name-field")
                .focused($isFocused)
                .onSubmit { isFocused = false }

            Spacer()
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "Done")) { isFocused = false }
            }
        }
        #endif
    }
}

private struct AccountSetupStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focusedField: AccountField?

    private enum AccountField { case name, balance }

    private let columns = [
        GridItem(.flexible(), spacing: VSpacing.md),
        GridItem(.flexible(), spacing: VSpacing.md),
    ]

    var body: some View {
        if vm.isAccountSubStepEnabled {
            ZStack {
                if vm.accountSubStep == .type {
                    typeSelectionStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    accountDetailsStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
        } else {
            combinedStep
        }
    }

    private var combinedStep: some View {
        ScrollView {
            VStack(spacing: VSpacing.lg) {
                Spacer(minLength: VSpacing.xl)

                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(VColors.primary)

                VStack(spacing: VSpacing.sm) {
                    Text(String(localized: "Set Up Your First Account"))
                        .font(VTypography.title2.bold())
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Create the account where you usually keep or move money. You can always add more later."))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                VStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "Account Name"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textSecondary)

                        TextField(String(localized: "Main Account"), text: $vm.accountName)
                            .padding(VSpacing.md)
                            .background(VColors.secondaryBackground)
                            .cornerRadius(VSpacing.cornerRadiusMD)
                            .accessibilityIdentifier("onboarding-account-name-field")
                            .focused($focusedField, equals: .name)
                            .onSubmit { focusedField = .balance }
                    }

                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "Opening Balance"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textSecondary)

                        HStack(spacing: VSpacing.sm) {
                            Text(vm.selectedCurrencyCode)
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.primary)
                                .padding(.horizontal, VSpacing.sm)
                                .padding(.vertical, VSpacing.xs)
                                .background(VColors.primary.opacity(0.12))
                                .cornerRadius(VSpacing.cornerRadiusSM)

                            TextField(String(localized: "0"), text: $vm.openingBalance)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                .textContentType(nil)
                                #endif
                                .accessibilityIdentifier("onboarding-opening-balance-field")
                                .focused($focusedField, equals: .balance)
                        }
                        .padding(VSpacing.md)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusMD)

                        Text(String(localized: "Use a positive amount for what you currently have in this account."))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "Account Type"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textSecondary)

                        LazyVGrid(columns: columns, spacing: VSpacing.md) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                accountTypeCard(for: type)
                            }
                        }
                    }
                }
                .padding(.horizontal, VSpacing.screenPadding)

                Spacer(minLength: VSpacing.xl)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "Done")) { focusedField = nil }
            }
        }
        #endif
    }

    private var typeSelectionStep: some View {
        ScrollView {
            VStack(spacing: VSpacing.lg) {
                Spacer(minLength: VSpacing.xl)

                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(VColors.primary)

                VStack(spacing: VSpacing.sm) {
                    Text(String(localized: "Set Up Your First Account"))
                        .font(VTypography.title2.bold())
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "What type of account would you like to create?"))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                LazyVGrid(columns: columns, spacing: VSpacing.md) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        accountTypeCard(for: type)
                    }
                }
                .padding(.horizontal, VSpacing.screenPadding)

                Spacer(minLength: VSpacing.xl)
            }
        }
    }

    private var accountDetailsStep: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: VSpacing.lg) {
                Spacer(minLength: VSpacing.xl)

                AccountTypeIcon(type: vm.selectedAccountType, size: 64)

                VStack(spacing: VSpacing.sm) {
                    Text(String(localized: "Account Details"))
                        .font(VTypography.title2.bold())
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Give your account a name and set your opening balance."))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VSpacing.xl)
                }

                VStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "Account Name"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textSecondary)

                        TextField(String(localized: "Main Account"), text: $vm.accountName)
                            .padding(VSpacing.md)
                            .background(VColors.secondaryBackground)
                            .cornerRadius(VSpacing.cornerRadiusMD)
                            .accessibilityIdentifier("onboarding-account-name-field")
                            .focused($focusedField, equals: .name)
                            .onSubmit { focusedField = .balance }
                    }

                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "Opening Balance"))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textSecondary)

                        HStack(spacing: VSpacing.sm) {
                            Text(vm.selectedCurrencyCode)
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.primary)
                                .padding(.horizontal, VSpacing.sm)
                                .padding(.vertical, VSpacing.xs)
                                .background(VColors.primary.opacity(0.12))
                                .cornerRadius(VSpacing.cornerRadiusSM)

                            TextField(String(localized: "0"), text: $vm.openingBalance)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                .textContentType(nil)
                                #endif
                                .accessibilityIdentifier("onboarding-opening-balance-field")
                                .focused($focusedField, equals: .balance)
                        }
                        .padding(VSpacing.md)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusMD)

                        Text(String(localized: "Use a positive amount for what you currently have in this account."))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textSecondary)
                    }
                }
                .padding(.horizontal, VSpacing.screenPadding)
                .id("account-fields")

                Spacer(minLength: VSpacing.xl)
            }
        }
        // With the keyboard up, the header eats the small visible window and
        // the balance field sits clipped below the fold. Bring the fields
        // group to the top whenever either field gains focus.
        .onChange(of: focusedField) { _, newValue in
            guard newValue != nil else { return }
            withAnimation {
                proxy.scrollTo("account-fields", anchor: .top)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "Done")) { focusedField = nil }
            }
        }
        #endif
        }
    }

    @ViewBuilder
    private func accountTypeCard(for type: AccountType) -> some View {
        Button {
            vm.selectedAccountType = type
        } label: {
            VStack(spacing: VSpacing.sm) {
                AccountTypeIcon(type: type, size: 40)
                Text(type.displayName)
                    .font(VTypography.caption1.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(VSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                    .fill(vm.selectedAccountType == type ? VColors.primary.opacity(0.12) : VColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                    .stroke(vm.selectedAccountType == type ? VColors.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityAddTraits(vm.selectedAccountType == type ? .isSelected : [])
        .accessibilityIdentifier("onboarding-account-type-\(type.rawValue)")
    }
}

private struct NotificationsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(VColors.primary)
                .accessibilityHidden(true)

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "Stay on top of your money"))
                    .font(VTypography.title2.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding-notifications-title")

                Text(String(localized: "Get gentle reminders for budgets, bills, and goals — only when you want them."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            VStack(alignment: .leading, spacing: VSpacing.md) {
                FeatureRow(icon: "target", color: .orange, text: String(localized: "Budget limit alerts"))
                FeatureRow(icon: "calendar.badge.clock", color: .blue, text: String(localized: "Bill and debt due dates"))
                FeatureRow(icon: "arrow.triangle.2.circlepath", color: .purple, text: String(localized: "Upcoming recurring transactions"))
            }
            .padding(.horizontal, VSpacing.xl)

            Toggle(isOn: $vm.wantsNotifications) {
                VStack(alignment: .leading, spacing: VSpacing.xxs) {
                    Text(String(localized: "Enable reminders"))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "You can change this anytime in Settings."))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                }
            }
            .padding(VSpacing.cardPadding)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            .padding(.horizontal, VSpacing.screenPadding)
            .accessibilityIdentifier("onboarding-notifications-toggle")

            Text(String(localized: "Vittora will ask for notification permission when you turn reminders on in Settings."))
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VSpacing.xl)

            Spacer()
        }
        .accessibilityIdentifier("onboarding-notifications-step")
    }
}

private struct DoneStepView: View {
    let vm: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Group {
                ZStack {
                    Circle()
                        .fill(VColors.primary)
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .if(!reduceMotion) { view in
                view.symbolEffect(.bounce)
            }
            .accessibilityHidden(true)

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "You're all set!"))
                    .font(VTypography.title1.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .accessibilityIdentifier("onboarding-done-title")
                Text(String(localized: "Vittora is ready to help you take control of your finances."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            VStack(spacing: VSpacing.sm) {
                onboardingSummaryRow(
                    title: String(localized: "Currency"),
                    value: vm.selectedCurrencyCode
                )
                onboardingSummaryRow(
                    title: String(localized: "First Account"),
                    value: vm.accountName
                )
                onboardingSummaryRow(
                    title: String(localized: "Account Type"),
                    value: vm.selectedAccountType.displayName
                )
            }
            .padding(VSpacing.cardPadding)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            .padding(.horizontal, VSpacing.screenPadding)

            Spacer()
        }
        .accessibilityIdentifier("onboarding-complete-step")
    }

    @ViewBuilder
    private func onboardingSummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(value)
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
        }
    }
}
