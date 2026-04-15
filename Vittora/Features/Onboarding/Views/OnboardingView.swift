import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = OnboardingViewModel()

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
                TabView(selection: .constant(vm.currentStep)) {
                    WelcomeStepView()
                        .tag(OnboardingViewModel.Step.welcome)
                    CurrencyStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.currency)
                    ProfileStepView(vm: vm)
                        .tag(OnboardingViewModel.Step.profile)
                    DoneStepView()
                        .tag(OnboardingViewModel.Step.done)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                .tabViewStyle(.automatic)
                #endif
                .animation(.easeInOut, value: vm.currentStep)

                // CTA button
                ctaButton
                    .padding(.horizontal, VSpacing.screenPadding)
                    .padding(.bottom, VSpacing.xxxl)
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.Step.allCases.filter { $0 != .done }, id: \.rawValue) { step in
                Capsule()
                    .fill(vm.currentStep.rawValue >= step.rawValue ? VColors.primary : VColors.primary.opacity(0.2))
                    .frame(width: vm.currentStep == step ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: vm.currentStep)
            }
        }
        .padding(.bottom, VSpacing.lg)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            if vm.currentStep == .profile {
                vm.advance()
            } else if vm.currentStep == .done {
                vm.complete(appState: appState)
            } else {
                vm.advance()
            }
        } label: {
            HStack {
                Text(buttonTitle)
                    .font(VTypography.bodyBold)
                if vm.currentStep != .done {
                    Image(systemName: "arrow.right")
                        .font(.body.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(VSpacing.md)
            .background(VColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD))
        }
        .disabled(!vm.canAdvance)
    }

    private var buttonTitle: String {
        switch vm.currentStep {
        case .welcome:  return String(localized: "Get Started")
        case .currency: return String(localized: "Continue")
        case .profile:  return String(localized: "Continue")
        case .done:     return String(localized: "Start Tracking")
        }
    }
}

// MARK: - Step Views

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Image(systemName: "indianrupeesign.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(VColors.primary)
                .symbolEffect(.pulse)

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "Welcome to Vittora"))
                    .font(VTypography.title1.bold())
                    .foregroundStyle(VColors.textPrimary)
                    .multilineTextAlignment(.center)

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

            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(VColors.income)

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
                            .padding(VSpacing.md)
                            .background(vm.selectedCurrencyCode == currency.code
                                        ? VColors.primary.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
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
                Text(String(localized: "Optional — you can change this in settings anytime."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            TextField(String(localized: "Your name"), text: $vm.userName)
                .font(VTypography.title3)
                .multilineTextAlignment(.center)
                .padding(VSpacing.md)
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusMD)
                .padding(.horizontal, VSpacing.xl)

            Spacer()
        }
    }
}

private struct DoneStepView: View {
    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(VColors.income)
                .symbolEffect(.bounce)

            VStack(spacing: VSpacing.sm) {
                Text(String(localized: "You're all set!"))
                    .font(VTypography.title1.bold())
                    .foregroundStyle(VColors.textPrimary)
                Text(String(localized: "Vittora is ready to help you take control of your finances."))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.xl)
            }

            Spacer()
        }
    }
}
