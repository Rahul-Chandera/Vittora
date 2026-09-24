import SwiftUI
import VittoraCore

/// Shopping mode (M3.3.1 / M3.3.2).
///
/// A deliberately small screen: name the shop, add amounts as you pick things up,
/// and the running total plus remaining budget appear on the Lock Screen and in
/// the Dynamic Island. The point of the feature is to be usable without opening
/// the app, so this screen exists mainly to start and stop the session.
///
/// Nothing here writes a transaction. A shopping session is a running tally, not
/// a ledger entry — turning each item into a transaction would fill the ledger
/// with fragments of one shop. The user records the actual purchase afterwards.
struct ShoppingModeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sessionName = ""
    @State private var amountText = ""
    @State private var runningTotal: Decimal = 0
    @State private var itemCount = 0
    @State private var isRunning = false
    @State private var error: String?

    private let controller = LiveActivityController.shared

    // The app's display currency, like every other screen — NOT the device
    // locale. The init this replaces defaulted to
    // `Locale.current.currency?.identifier`, and AppTabView constructs this
    // view with no argument, so a US ledger on a device set to India showed a
    // running total of "₹0.00" while the rest of the app showed dollars. The
    // Live Activity inherited it, so the Lock Screen and Dynamic Island were
    // wrong too.
    @Environment(\.currencyCode) private var currencyCode

    var body: some View {
        NavigationStack {
            Form {
                if !controller.areActivitiesEnabled {
                    Section {
                        Text(String(localized: "Live Activities are switched off for Vittora. Turn them on in Settings to see your running total on the Lock Screen."))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                }

                if isRunning {
                    runningSection
                    addItemSection
                } else {
                    startSection
                }
            }
            .navigationTitle(String(localized: "Shopping Mode"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        Task {
                            // Ending the session on dismiss, deliberately: an
                            // activity left running with a total the user has
                            // stopped adding to reads as current when it is not.
                            if isRunning { await controller.endShoppingSession() }
                            dismiss()
                        }
                    }
                }
            }
            .errorAlert(message: $error)
        }
    }

    private var startSection: some View {
        Section {
            TextField(String(localized: "Shop name (optional)"), text: $sessionName)
                .accessibilityIdentifier("shopping-mode-name-field")

            Button {
                start()
            } label: {
                Label(String(localized: "Start Session"), systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
            .disabled(!controller.areActivitiesEnabled)
            .accessibilityIdentifier("shopping-mode-start-button")
        } footer: {
            Text(String(localized: "Your running total appears on the Lock Screen and in the Dynamic Island. Nothing is added to your transactions — record the purchase when you are done."))
        }
    }

    private var runningSection: some View {
        Section {
            HStack {
                Text(String(localized: "Running total"))
                Spacer()
                Text(runningTotal.formatted(.currency(code: currencyCode)))
                    .font(VTypography.bodyBold)
                    .monospacedDigit()
                    .accessibilityIdentifier("shopping-mode-total")
            }
            HStack {
                Text(String(localized: "Items"))
                Spacer()
                Text("\(itemCount)")
                    .foregroundStyle(VColors.textSecondary)
                    .monospacedDigit()
            }
            Button(role: .destructive) {
                Task {
                    await controller.endShoppingSession()
                    isRunning = false
                    runningTotal = 0
                    itemCount = 0
                }
            } label: {
                Label(String(localized: "End Session"), systemImage: "stop.circle")
            }
            .accessibilityIdentifier("shopping-mode-end-button")
        }
    }

    private var addItemSection: some View {
        Section {
            HStack {
                TextField(String(localized: "Amount"), text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityIdentifier("shopping-mode-amount-field")

                Button(String(localized: "Add")) {
                    addItem()
                }
                .buttonStyle(.bordered)
                .disabled(Decimal(localizedAmount: amountText) == nil)
            }
        } header: {
            VFormSectionHeader(String(localized: "Add Item"))
        }
    }

    private func start() {
        let started = controller.startShoppingSession(
            name: sessionName,
            currencyCode: currencyCode
        )
        guard started else {
            error = String(localized: "We couldn't start the Live Activity. Check that Live Activities are on for Vittora.")
            return
        }
        isRunning = true
        runningTotal = 0
        itemCount = 0
    }

    private func addItem() {
        guard let amount = Decimal(localizedAmount: amountText), amount > 0 else { return }
        // The screen mirrors what the activity will show rather than reading it
        // back, so the two cannot drift apart while the update is in flight.
        runningTotal += amount
        itemCount += 1
        amountText = ""
        Task { await controller.updateShoppingSession(addingAmount: amount) }
    }
}

#Preview {
    ShoppingModeView()
}
