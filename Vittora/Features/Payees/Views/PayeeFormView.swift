import SwiftUI

struct PayeeFormView: View {
    var editingPayee: PayeeEntity? = nil
    var onSave: (() -> Void)? = nil

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
        .navigationTitle(editingPayee == nil ? "New Payee" : "Edit Payee")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
            }
        }
        .task {
            setupViewModel()
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
            Section("Type") {
                Picker("Payee Type", selection: Bindable(vm).selectedType) {
                    HStack {
                        Image(systemName: "building.2.fill")
                        Text("Business")
                    }.tag(PayeeType.business)
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Person")
                    }.tag(PayeeType.person)
                }
                .pickerStyle(.segmented)
            }

            Section("Details") {
                TextField("Name", text: Bindable(vm).name)
            }

            Section("Contact (Optional)") {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(VColors.textTertiary)
                        .frame(width: 24)
                    TextField("Phone", text: Bindable(vm).phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }

                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(VColors.textTertiary)
                        .frame(width: 24)
                    TextField("Email", text: Bindable(vm).email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
            }

            Section("Notes") {
                TextField("Notes (optional)", text: Bindable(vm).notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let error = saveError {
                Section {
                    Text(error)
                        .foregroundColor(VColors.expense)
                        .font(VTypography.caption1)
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
