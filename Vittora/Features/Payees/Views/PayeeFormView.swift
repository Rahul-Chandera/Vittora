import SwiftUI

struct PayeeFormView: View {
    var editingPayee: PayeeEntity? = nil
    var onSave: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PayeeFormViewModel?
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(editingPayee == nil ? String(localized: "New Payee") : String(localized: "Edit Payee"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
            }
        }
        .task {
            setupViewModel()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func setupViewModel() {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let payeeRepo = deps.payeeRepository else { return }

        let vm = PayeeFormViewModel(
            createUseCase: CreatePayeeUseCase(repository: payeeRepo),
            updateUseCase: UpdatePayeeUseCase(repository: payeeRepo)
        )
        if let payee = editingPayee {
            vm.loadPayee(payee)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func formContent(vm: PayeeFormViewModel) -> some View {
        Form {
            Section(String(localized: "Type")) {
                Picker(String(localized: "Payee Type"), selection: Bindable(vm).selectedType) {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text(String(localized: "Business"))
                    }.tag(PayeeType.business)
                    HStack {
                        Image(systemName: "person.fill")
                        Text(String(localized: "Person"))
                    }.tag(PayeeType.person)
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "Details")) {
                TextField(String(localized: "Name"), text: Bindable(vm).name)
                    #if os(iOS)
                    .textContentType(.name)
                    #endif
            }

            Section(String(localized: "Contact (Optional)")) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(VColors.textTertiary)
                        .frame(width: 24)
                    TextField(String(localized: "Phone"), text: Bindable(vm).phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        #endif
                }

                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(VColors.textTertiary)
                        .frame(width: 24)
                    TextField(String(localized: "Email"), text: Bindable(vm).email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
            }

            Section(String(localized: "Notes")) {
                TextField(String(localized: "Notes (optional)"), text: Bindable(vm).notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let error = saveError {
                Section {
                    VInlineErrorText(error)
                }
            }
        }
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
            appState.notifyDataChanged()
            onSave?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        PayeeFormView()
    }
}
