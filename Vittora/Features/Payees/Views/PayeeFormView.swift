import SwiftUI
import VittoraCore

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
                .vDialogCancelButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
                .vDialogConfirmButton()
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

        let vm = PayeeFormViewModel(
            createUseCase: CreatePayeeUseCase(repository: dependencies.payeeRepository),
            updateUseCase: UpdatePayeeUseCase(repository: dependencies.payeeRepository)
        )
        if let payee = editingPayee {
            vm.loadPayee(payee)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func formContent(vm: PayeeFormViewModel) -> some View {
        Form {
            Section {
                // Segmented segments must be a single Text/Image; composite
                // (HStack of icon + text) content breaks tap selection.
                Picker(String(localized: "Payee Type"), selection: Bindable(vm).selectedType) {
                    Text(String(localized: "Business")).tag(PayeeType.business)
                    Text(String(localized: "Person")).tag(PayeeType.person)
                }
                .pickerStyle(.menu)
            } header: {
                VFormSectionHeader(String(localized: "Type"))
            }
            .headerProminence(.increased)

            Section {
                TextField(String(localized: "Name"), text: Bindable(vm).name)
                    #if os(iOS)
                    .textContentType(.name)
                    #endif
            } header: {
                VFormSectionHeader(String(localized: "Details"))
            }
            .headerProminence(.increased)

            Section {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(VColors.textPrimary)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    TextField(String(localized: "Phone"), text: Bindable(vm).phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        #endif
                }

                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(VColors.textPrimary)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    TextField(String(localized: "Email"), text: Bindable(vm).email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
            } header: {
                VFormSectionHeader(String(localized: "Contact (Optional)"))
            }
            .headerProminence(.increased)

            Section {
                TextField(String(localized: "Notes (optional)"), text: Bindable(vm).notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                VFormSectionHeader(String(localized: "Notes"))
            }
            .headerProminence(.increased)

            if let error = saveError {
                Section {
                    VInlineErrorText(error)
                }
            }
        }
        .tint(VColors.textCursor)
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
            appState.notifyChanged(.payees)
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
