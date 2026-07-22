import SwiftUI
import VittoraCore

struct WatchQuickExpenseView: View {
    @Bindable var store: WatchSnapshotStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = WatchExpenseAmount(crownSteps: 1)
    @State private var typedAmount = ""
    @State private var isTyping = false
    @State private var typedAmountIsInvalid = false
    @FocusState private var amountIsFocused: Bool

    private var currencyCode: String {
        store.snapshot?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button {
                    typedAmount = amount.decimal.formatted()
                    typedAmountIsInvalid = false
                    isTyping = true
                } label: {
                    Text(amount.decimal, format: .currency(code: currencyCode))
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.bordered)
                .focusable()
                .focused($amountIsFocused)
                .digitalCrownRotation(
                    crownBinding,
                    from: 0,
                    through: Double(WatchExpenseAmount.maximumCents / WatchExpenseAmount.crownStepCents),
                    by: 1,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .accessibilityLabel(String(localized: "Expense amount"))
                .accessibilityValue(amount.decimal.formatted(.currency(code: currencyCode)))
                .accessibilityHint(String(localized: "Turn the Digital Crown to adjust, or tap to type."))

                NavigationLink {
                    WatchCategoryGridView(
                        store: store,
                        amount: amount.decimal,
                        onQueued: { dismiss() }
                    )
                } label: {
                    Text(String(localized: "Choose category"))
                }
                .disabled(amount.cents == 0 || store.snapshot?.quickCategories.isEmpty != false)
            }
            .navigationTitle(String(localized: "Amount"))
            .onAppear {
                amountIsFocused = true
            }
            .onChange(of: isTyping) { _, isTyping in
                if !isTyping {
                    amountIsFocused = true
                }
            }
            .onChange(of: amount.cents) { _, _ in
                AccessibilityNotification.Announcement(
                    amount.decimal.formatted(.currency(code: currencyCode))
                ).post()
            }
            .sheet(isPresented: $isTyping) {
                VStack {
                    TextField(String(localized: "Amount"), text: $typedAmount)
                        .accessibilityLabel(String(localized: "Expense amount"))
                    if typedAmountIsInvalid {
                        Text(String(localized: "Enter a positive amount with no more than two decimal places."))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Button(String(localized: "Set amount")) {
                        if amount.setTypedAmount(typedAmount) {
                            isTyping = false
                        } else {
                            typedAmountIsInvalid = true
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var crownBinding: Binding<Double> {
        Binding(
            get: { Double(amount.crownSteps) },
            set: { amount.setCrownSteps(Int($0.rounded())) }
        )
    }
}

private struct WatchCategoryGridView: View {
    @Bindable var store: WatchSnapshotStore
    let amount: Decimal
    let onQueued: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.snapshot?.quickCategories ?? []) { category in
                    NavigationLink {
                        WatchExpenseConfirmationView(
                            store: store,
                            amount: amount,
                            category: category,
                            onQueued: onQueued
                        )
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.title3)
                                .foregroundStyle(Color(watchHex: category.colorHex))
                            Text(category.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.name)
                    .accessibilityHint(String(localized: "Select category"))
                }
            }
        }
        .navigationTitle(String(localized: "Category"))
    }
}

private struct WatchExpenseConfirmationView: View {
    @Bindable var store: WatchSnapshotStore
    let amount: Decimal
    let category: WatchSnapshotCategory
    let onQueued: () -> Void

    private var currencyCode: String {
        store.snapshot?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(Color(watchHex: category.colorHex))
            Text(category.name)
            Text(amount, format: .currency(code: currencyCode))
                .font(.headline)
            Button(String(localized: "Queue expense")) {
                if store.enqueueExpense(amount: amount, categoryID: category.id) {
                    onQueued()
                }
            }
            .accessibilityLabel(
                String(localized: "Queue \(amount.formatted(.currency(code: currencyCode))) for \(category.name)")
            )
        }
        .navigationTitle(String(localized: "Confirm"))
    }
}

private extension Color {
    init(watchHex value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&rgb) else {
            self = .blue
            return
        }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
