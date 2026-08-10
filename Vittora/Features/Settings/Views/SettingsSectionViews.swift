import SwiftUI
import VittoraCore

// MARK: - Profile Settings

struct ProfileSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @State private var editingName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Your name"), text: $editingName)
                    #if os(iOS)
                    .textContentType(.name)
                    #endif
            } header: {
                VFormSectionHeader(String(localized: "Display Name"))
                    .foregroundStyle(VColors.textPrimary)
            }
        }
        .navigationTitle(String(localized: "Profile"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { editingName = vm.userName }
        .onChange(of: editingName) { _, new in
            Task { await vm.updateUserName(new) }
        }
    }
}

// MARK: - Currency Settings

struct CurrencySettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                ForEach(vm.supportedCurrencies, id: \.code) { currency in
                    Button {
                        vm.selectedCurrencyCode = currency.code
                    } label: {
                        HStack {
                            // Same flag treatment as onboarding — see
                            // currencyFlagImage for why it is an Image and not
                            // a Text. Dropped at accessibility sizes, where the
                            // row needs its width for the name.
                            if !dynamicTypeSize.isAccessibilitySize,
                               let flag = currencyFlagImage(for: currency.code) {
                                flag
                                    .accessibilityHidden(true)
                            }
                            Text(currency.name)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if vm.selectedCurrencyCode == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.primaryOnSurface)
                                    .accessibilityHidden(true)
                            }
                        }
                        // Make the whole row tappable, not just the text.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        vm.selectedCurrencyCode == currency.code
                        ? String(localized: "Selected")
                        : String(localized: "Not selected")
                    )
                }
            } header: {
                VFormSectionHeader(String(localized: "Select Currency"))
                    .foregroundStyle(VColors.textPrimary)
            }
        }
        .navigationTitle(String(localized: "Currency"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var draftMode: SettingsViewModel.AppearanceMode?
    @State private var draftAccent: SettingsViewModel.AccentColor?
    /// Applying used to be silent: the button just greyed out, which reads as
    /// "nothing happened" rather than "done".
    @State private var didApplyAppearance = false

    var body: some View {
        Form {
            Section {
                ForEach(SettingsViewModel.AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        draftMode = mode
                    } label: {
                        HStack {
                            Text(mode.displayName)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.textPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                        // Make the whole row tappable, not just the text.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        selectedMode == mode
                        ? String(localized: "Selected")
                        : String(localized: "Not selected")
                    )
                }
            } header: {
                VFormSectionHeader(String(localized: "Theme"))
            }
            .headerProminence(.increased)

            Section {
                ForEach(SettingsViewModel.AccentColor.allCases, id: \.self) { accent in
                    Button {
                        draftAccent = accent
                    } label: {
                        HStack {
                            Circle()
                                // The stroke below draws the boundary, so the fill
                                // can be the real accent — a swatch that cannot show
                                // its own colour is not a swatch.
                                .fill(VColors.accent(accent))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    // Hairline so a light swatch still has an edge on
                                    // white, without a heavy black ring dominating it.
                                    Circle().strokeBorder(VColors.textPrimary.opacity(0.18), lineWidth: 1)
                                }
                                .accessibilityHidden(true)
                            Text(accent.displayName)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if selectedAccent == accent {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.textPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(
                        selectedAccent == accent
                        ? String(localized: "Selected")
                        : String(localized: "Not selected")
                    )
                }
            } header: {
                VFormSectionHeader(String(localized: "Accent Color"))
            }
            .headerProminence(.increased)

            Section {
                Text(String(localized: "Live Preview"))
                    .font(.headline)
                    .foregroundStyle(VColors.textPrimary)

                VStack(alignment: .leading, spacing: VSpacing.md) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(previewAccent)
                            .accessibilityHidden(true)
                        Text(String(localized: "Monthly overview"))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(previewTextPrimary)
                        Spacer()
                        Text(verbatim: "72%")
                            .foregroundStyle(previewTextPrimary)
                    }

                    // Decorative: this bar exists to show what the accent looks
                    // like, and the row above already reads "Monthly overview,
                    // 72%". Exposing it as its own element made a 4pt-tall
                    // accessibility target, which the audit flags as too small
                    // to interact with.
                    ProgressView(value: 0.72)
                        .tint(previewAccent)
                        .accessibilityHidden(true)

                    Text(String(localized: "See how text, surfaces, and your accent work together."))
                        .font(VTypography.body)
                        .foregroundStyle(previewTextPrimary)
                }
                .padding(VSpacing.md)
                .background(previewSurface)
                .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD, style: .continuous))
                .padding(.vertical, VSpacing.xs)
                .listRowBackground(previewBackground)
                .accessibilityIdentifier("appearance-live-preview")
            }
            .headerProminence(.increased)

            Section {
                Button {
                    guard selectedMode != vm.appearanceMode || selectedAccent != vm.accentColor else { return }
                    vm.appearanceMode = selectedMode
                    vm.accentColor = selectedAccent
                    withAnimation { didApplyAppearance = true }
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { didApplyAppearance = false }
                    }
                } label: {
                    HStack(spacing: VSpacing.xs) {
                        if didApplyAppearance {
                            Image(systemName: "checkmark.circle.fill")
                                .accessibilityHidden(true)
                            Text(String(localized: "Appearance Applied"))
                        } else {
                            Text(String(localized: "Apply Appearance"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                // VoiceOver gets the same confirmation the sighted user sees.
                .accessibilityValue(didApplyAppearance ? String(localized: "Applied") : "")
                .frame(maxWidth: .infinity)
                .accessibilityRespondsToUserInteraction(
                    selectedMode != vm.appearanceMode || selectedAccent != vm.accentColor
                )
                .accessibilityIdentifier("appearance-apply-button")
            }
        }
        // Clearance for the floating tab bar. safeAreaPadding, not
        // safeAreaInset: an inset paints an opaque view OVER the list, and
        // rows passing behind it are sliced mid-glyph. The Appearance
        // screen's Live Preview card was cut that way, and the audit's
        // contrast sampler reads the surviving sliver as failing text.
        // Padding reserves the same space without drawing.
        //
        // The plain ScrollView screens keep their inset: removing it there
        // lets content render in the gutter below the tab bar, which the
        // audit reports as text with no accessible element.
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(String(localized: "Appearance"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            draftMode = vm.appearanceMode
            draftAccent = vm.accentColor
        }
    }

    private var selectedMode: SettingsViewModel.AppearanceMode {
        draftMode ?? vm.appearanceMode
    }

    private var selectedAccent: SettingsViewModel.AccentColor {
        draftAccent ?? vm.accentColor
    }

    private var previewColorScheme: ColorScheme {
        selectedMode.colorScheme ?? systemColorScheme
    }

    private var previewAccent: Color {
        VColors.accent(selectedAccent, for: previewColorScheme)
    }

    private var previewBackground: Color {
        if selectedMode == .oledBlack { return .black }
        return previewColorScheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : .white
    }

    private var previewSurface: Color {
        previewColorScheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.18)
            : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private var previewTextPrimary: Color {
        previewColorScheme == .dark ? .white : .black
    }

    private var previewTextSecondary: Color {
        previewColorScheme == .dark
            ? Color(red: 0.820, green: 0.820, blue: 0.839)
            : Color(red: 0.184, green: 0.184, blue: 0.200)
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDisablingAppLock = false

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { vm.isAppLockEnabled },
            set: { newValue in
                if newValue {
                    Task { await vm.updateAppLockEnabled(true) }
                } else {
                    Task { await disableAppLockIfNeeded() }
                }
            }
        )
    }

    private var passcodeFallbackBinding: Binding<Bool> {
        Binding(
            get: { vm.allowPasscodeFallback },
            set: { newValue in
                Task { await vm.updateAllowPasscodeFallback(newValue) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "App Lock"), isOn: appLockBinding)
                    .disabled(isDisablingAppLock)
            } footer: {
                Text(String(localized: "Require biometrics or passcode when opening Vittora."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isAppLockEnabled {
                Section {
                    ForEach(AppLockTimeout.allCases, id: \.self) { timeout in
                        Button {
                            vm.appLockTimeout = timeout
                        } label: {
                            HStack {
                                Text(timeout.displayName)
                                    .foregroundStyle(VColors.textPrimary)
                                Spacer()
                                if vm.appLockTimeout == timeout {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(VColors.primaryOnSurface)
                                        .accessibilityHidden(true)
                                }
                            }
                            // Make the whole row tappable, not just the text.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(
                            vm.appLockTimeout == timeout
                            ? String(localized: "Selected")
                            : String(localized: "Not selected")
                        )
                    }
                } header: {
                    VFormSectionHeader(String(localized: "Lock After"))
                } footer: {
                    Text(String(localized: "Require authentication again after the app has been in the background for this long."))
                        .foregroundStyle(VColors.textSecondary)
                }

                Section {
                    Toggle(String(localized: "Passcode Fallback"), isOn: passcodeFallbackBinding)
                } footer: {
                    Text(String(localized: "Allow your device passcode if biometric authentication fails."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }

            if DeviceSecurityAssessment.isLikelyCompromisedEnvironment {
                Section {
                    Label {
                        Text(String(localized: "Modified device environment detected"))
                            .font(VTypography.caption1)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VColors.warning)
                    }
                } footer: {
                    Text(String(localized: "For your security, avoid storing highly sensitive data on modified devices. This check is informational only."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
        .navigationTitle(String(localized: "Security"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(reduceMotion ? nil : .default, value: vm.isAppLockEnabled)
    }

    private func disableAppLockIfNeeded() async {
        guard vm.isAppLockEnabled else { return }
        isDisablingAppLock = true
        defer { isDisablingAppLock = false }
        _ = await vm.disableAppLockIfAuthenticated(using: dependencies.biometricService)
    }
}

// MARK: - Search Privacy (Spotlight)

struct PrivacySearchSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dependencies) private var dependencies
    @State private var isUpdatingIndex = false

    private var spotlightBinding: Binding<Bool> {
        Binding(
            get: { vm.isSpotlightIndexingEnabled },
            set: { newValue in
                Task { await applySpotlightToggle(enabled: newValue) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Show transactions in Search"), isOn: spotlightBinding)
                    .disabled(isUpdatingIndex)
                    .accessibilityIdentifier("settings-spotlight-indexing-toggle")
            } footer: {
                Text(String(localized: "When on, recent transactions appear in Spotlight and system Search. Amounts can be visible without unlocking Vittora. Turning this off removes them from Search immediately."))
                    .foregroundStyle(VColors.textSecondary)
            }
        }
        .navigationTitle(String(localized: "Search Privacy"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func applySpotlightToggle(enabled: Bool) async {
        isUpdatingIndex = true
        defer { isUpdatingIndex = false }
        vm.isSpotlightIndexingEnabled = enabled
        if enabled {
            UserDefaults.standard.set(true, forKey: TransactionSpotlightIndex.needsFullReindexKey)
            let coordinator = TransactionSpotlightCoordinator(
                transactionRepository: dependencies.transactionRepository,
                payeeRepository: dependencies.payeeRepository,
                categoryRepository: dependencies.categoryRepository
            )
            await coordinator.syncNow(forceFullReindex: true)
        } else {
            await TransactionSpotlightIndex.deleteAllIndexedTransactions()
        }
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        SyncDetailView()
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    var body: some View {
        DataManagementView()
    }
}

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @Bindable var vm: SettingsViewModel
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isApplyingMasterToggle = false
    @State private var permissionDeniedMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "Enable Notifications"),
                    isOn: Binding(
                        get: { vm.isNotificationsEnabled },
                        set: { newValue in
                            Task { await handleMasterToggle(enabled: newValue) }
                        }
                    )
                )
                .disabled(isApplyingMasterToggle)
            } footer: {
                Text(String(localized: "Receive reminders for bill due dates, budget limits, and goal milestones."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if vm.isNotificationsEnabled {
                Section {
                    Toggle(String(localized: "Bill & Debt Due Dates"), isOn: $vm.notifyBillsDue)
                        .onChange(of: vm.notifyBillsDue) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Budget Limit Alerts"), isOn: $vm.notifyBudgetAlerts)
                        .onChange(of: vm.notifyBudgetAlerts) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Goal Milestones"), isOn: $vm.notifyGoalMilestones)
                        .onChange(of: vm.notifyGoalMilestones) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                    Toggle(String(localized: "Recurring Transactions"), isOn: $vm.notifyRecurringTransactions)
                        .onChange(of: vm.notifyRecurringTransactions) { _, _ in
                            Task { await applySubToggleChange() }
                        }
                } header: {
                    VFormSectionHeader(String(localized: "Reminders"))
                }

                Section {
                    DatePicker(
                        String(localized: "Preferred Delivery Time"),
                        selection: $vm.notificationDeliveryTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: vm.notificationDeliveryTime) { _, _ in
                        Task { await applySchedulingChange() }
                    }

                    Picker(String(localized: "Bill Reminder"), selection: $vm.billReminderLeadDays) {
                        ForEach(NotificationSchedulePreferences.supportedBillLeadDays, id: \.self) { days in
                            Text(billLeadTimeLabel(days))
                                .tag(days)
                        }
                    }
                    .onChange(of: vm.billReminderLeadDays) { _, _ in
                        Task { await applySchedulingChange() }
                    }
                } header: {
                    VFormSectionHeader(String(localized: "Schedule"))
                }

                Section {
                    Toggle(
                        String(localized: "Enable Quiet Hours"),
                        isOn: $vm.notificationQuietHoursEnabled
                    )
                    .onChange(of: vm.notificationQuietHoursEnabled) { _, _ in
                        Task { await applySchedulingChange() }
                    }

                    if vm.notificationQuietHoursEnabled {
                        DatePicker(
                            String(localized: "Start"),
                            selection: $vm.notificationQuietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: vm.notificationQuietHoursStart) { _, _ in
                            Task { await applySchedulingChange() }
                        }
                        DatePicker(
                            String(localized: "End"),
                            selection: $vm.notificationQuietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: vm.notificationQuietHoursEnd) { _, _ in
                            Task { await applySchedulingChange() }
                        }
                    }
                } header: {
                    VFormSectionHeader(String(localized: "Quiet Hours"))
                } footer: {
                    Text(String(localized: "Notifications scheduled during quiet hours are delivered when quiet hours end."))
                        .foregroundStyle(VColors.textSecondary)
                }
            }
        }
        .navigationTitle(String(localized: "Notifications"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .animation(reduceMotion ? nil : .default, value: vm.isNotificationsEnabled)
        .alert(
            String(localized: "Notifications Unavailable"),
            isPresented: Binding(
                get: { permissionDeniedMessage != nil },
                set: { if !$0 { permissionDeniedMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                permissionDeniedMessage = nil
            }
        } message: {
            if let permissionDeniedMessage {
                Text(permissionDeniedMessage)
            }
        }
    }

    private func notificationPreferencesUseCase() -> ApplyNotificationPreferencesUseCase {
        ApplyNotificationPreferencesUseCase(
            notificationService: dependencies.notificationService,
            refreshAllSchedules: { @MainActor in
                await dependencies.refreshAllNotificationSchedules()
            }
        )
    }

    @MainActor
    private func handleMasterToggle(enabled: Bool) async {
        let useCase = notificationPreferencesUseCase()

        isApplyingMasterToggle = true
        defer { isApplyingMasterToggle = false }

        if enabled {
            do {
                let granted = try await useCase.enableNotifications()
                vm.isNotificationsEnabled = granted
                if !granted {
                    permissionDeniedMessage = String(
                        localized: "Notification permission was denied. Enable notifications in System Settings to receive reminders."
                    )
                }
            } catch {
                vm.isNotificationsEnabled = false
                permissionDeniedMessage = error.localizedDescription
            }
        } else {
            await useCase.disableNotifications()
            vm.isNotificationsEnabled = false
        }
    }

    @MainActor
    private func applySubToggleChange() async {
        await notificationPreferencesUseCase().applySubToggleChange()
    }

    @MainActor
    private func applySchedulingChange() async {
        await notificationPreferencesUseCase().applySchedulingChange()
    }

    private func billLeadTimeLabel(_ days: Int) -> String {
        switch days {
        case 0:
            String(localized: "Same day")
        case 1:
            String(localized: "1 day before")
        default:
            String(localized: "\(days) days before")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    let vm: SettingsViewModel

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(localized: "Version"))
                    Spacer()
                    Text("v\(vm.appVersion) (\(vm.buildNumber))")
                        .foregroundStyle(VColors.textPrimary)
                }
                HStack {
                    Text(String(localized: "Platform"))
                    Spacer()
                    #if os(iOS)
                    Text(String(localized: "iOS"))
                        .foregroundStyle(VColors.textPrimary)
                    #elseif os(macOS)
                    Text(String(localized: "macOS"))
                        .foregroundStyle(VColors.textSecondary)
                    #endif
                }
            }

            Section {
                NavigationLink(String(localized: "Privacy Policy")) {
                    LegalDocumentView(document: .privacyPolicy)
                }
                NavigationLink(String(localized: "Terms of Service")) {
                    LegalDocumentView(document: .termsOfService)
                }
            } header: {
                VFormSectionHeader(String(localized: "Legal"))
            }
            .headerProminence(.increased)

            Section {
                VStack(spacing: VSpacing.sm) {
                    Image("OnboardingAppLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    Text(String(localized: "Vittora"))
                        .font(VTypography.title3.bold())
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Your personal finance companion"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VSpacing.md)
            }
        }
        .navigationTitle(String(localized: "About Vittora"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
