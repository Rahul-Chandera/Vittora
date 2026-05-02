import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                // Step content
                TabView(selection: currentStepBinding) {
                    WelcomeStepView()
                        .tag(OnboardingViewModel.Step.welcome)
                    CurrencyStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.currency)
                    ProfileStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.profile)
                    AccountSetupStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.account)
                    DoneStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.done)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                .tabViewStyle(.automatic)
                #endif
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
        case .account:  return String(localized: "Review Setup")
        case .done:     return String(localized: "Start Tracking")
        }
    }

    private var currentStepBinding: Binding<OnboardingViewModel.Step> {
        Binding(
            get: { vm.currentStep },
            set: { vm.currentStep = $0 }
        )
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
                Image(systemName: "dollarsign")
                    .font(.system(size: 40, weight: .medium))
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
}

private struct ProfileStepView: View {
    @Bindable var vm: OnboardingViewModel

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

            Spacer()
        }
    }
}

private struct AccountSetupStepView: View {
    @Bindable var vm: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: VSpacing.md),
        GridItem(.flexible(), spacing: VSpacing.md),
    ]

    var body: some View {
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
    }

    @ViewBuilder
    private func accountTypeCard(for type: AccountType) -> some View {
        Button {
            vm.selectedAccountType = type
        } label: {
            VStack(spacing: VSpacing.sm) {
                AccountTypeIcon(type: type, size: 40)
                Text(type.onboardingDisplayName)
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
        .accessibilityIdentifier("onboarding-account-type-\(type.rawValue)")
    }
}

private struct DoneStepView: View {
    let vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VColors.primary)
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .symbolEffect(.bounce)

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
                    value: vm.selectedAccountType.onboardingDisplayName
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

private extension AccountType {
    var onboardingDisplayName: String {
        switch self {
        case .cash:
            String(localized: "Cash")
        case .bank:
            String(localized: "Bank")
        case .creditCard:
            String(localized: "Credit Card")
        case .loan:
            String(localized: "Loan")
        case .digitalWallet:
            String(localized: "Digital Wallet")
        case .investment:
            String(localized: "Investment")
        case .receivable:
            String(localized: "Receivable")
        case .payable:
            String(localized: "Payable")
        }
    }
}
