import SwiftUI
import VittoraCore

/// "Ask about your money": a question in, an answer computed from the user's records out.
struct AskMoneyView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AskMoneyViewModel?
    @FocusState private var questionFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "Ask About Your Money"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .task {
            if vm == nil { vm = dependencies.makeAskMoneyViewModel() }
        }
    }

    @ViewBuilder
    private func content(_ vm: AskMoneyViewModel) -> some View {
        Form {
            Section {
                TextField(
                    String(localized: "For example: how much did I spend on dining last month?"),
                    text: Bindable(vm).questionText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .focused($questionFocused)
                .submitLabel(.search)
                .onSubmit { ask(vm) }
                .accessibilityIdentifier("ask-money-question-field")

                Button(String(localized: "Ask")) { ask(vm) }
                    .disabled(!vm.canAsk)
                    .accessibilityIdentifier("ask-money-ask-button")
            } footer: {
                Text(String(localized: "Answers come from the transactions on this device. Nothing is sent anywhere."))
            }

            if vm.isAnswering {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if let answer = vm.answer {
                Section {
                    Text(answer.text)
                        .font(VTypography.title3)
                        .foregroundStyle(VColors.textPrimary)
                        .accessibilityIdentifier("ask-money-answer")
                } header: {
                    VFormSectionHeader(vm.askedQuestion ?? String(localized: "Answer"))
                } footer: {
                    if vm.understoodByModel {
                        Label(
                            String(localized: "Apple Intelligence understood the question on this device. Every figure is calculated from your records."),
                            systemImage: "apple.intelligence"
                        )
                    }
                }

                if !answer.transactions.isEmpty {
                    Section(header: VFormSectionHeader(String(localized: "Transactions"))) {
                        ForEach(answer.transactions) { transaction in
                            row(transaction, payee: transaction.payeeID.flatMap { vm.payeeNames[$0] })
                        }
                    }
                }
            }

            Section(header: VFormSectionHeader(String(localized: "Try Asking"))) {
                ForEach(AskMoneyViewModel.Suggestion.all) { suggestion in
                    Button(suggestion.title) {
                        questionFocused = false
                        Task { await vm.ask(suggestion, currencyCode: currencyCode) }
                    }
                    .accessibilityIdentifier("ask-money-suggestion-\(suggestion.id)")
                }
            }
        }
        .errorAlert(message: Binding(get: { vm.error }, set: { vm.error = $0 }))
    }

    private func ask(_ vm: AskMoneyViewModel) {
        guard vm.canAsk else { return }
        questionFocused = false
        Task { await vm.askTypedQuestion(currencyCode: currencyCode) }
    }

    private func row(_ transaction: TransactionEntity, payee: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(payee ?? transaction.note ?? transaction.type.displayName)
                    .foregroundStyle(VColors.textPrimary)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            Spacer()
            Text(CurrencyFormatter.format(transaction.amount, currencyCode: transaction.currencyCode))
                .foregroundStyle(transaction.type == .income ? VColors.income : VColors.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
