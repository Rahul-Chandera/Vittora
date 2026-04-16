import SwiftUI

@Observable
@MainActor
final class ExportViewModel {
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var endDate: Date = .now
    var selectedFormat: ExportFormat = .csv
    var isExporting = false
    var exportURL: URL?
    var error: String?

    var useCustomDateRange = false

    private let exportService: any DataExportServiceProtocol

    init(exportService: any DataExportServiceProtocol) {
        self.exportService = exportService
    }

    func export() async {
        isExporting = true
        error = nil
        exportURL = nil
        defer { isExporting = false }

        do {
            exportURL = try await exportService.exportTransactions(
                startDate: useCustomDateRange ? startDate : nil,
                endDate: useCustomDateRange ? endDate : nil,
                format: selectedFormat
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ExportView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: ExportViewModel?
    @State private var showShareSheet = false

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Export Data"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil, let repo = dependencies.transactionRepository else { return }
            vm = ExportViewModel(
                exportService: DataExportService(
                    transactionRepository: repo,
                    accountRepository: dependencies.accountRepository,
                    categoryRepository: dependencies.categoryRepository,
                    payeeRepository: dependencies.payeeRepository
                )
            )
        }
    }

    @ViewBuilder
    private func content(_ vm: ExportViewModel) -> some View {
        Form {
            // Format
            Section(String(localized: "Format")) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button {
                        vm.selectedFormat = format
                    } label: {
                        HStack {
                            Text(format.rawValue)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            if vm.selectedFormat == format {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VColors.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Date range
            Section {
                Toggle(String(localized: "Custom date range"), isOn: Bindable(vm).useCustomDateRange)

                if vm.useCustomDateRange {
                    DatePicker(
                        String(localized: "From"),
                        selection: Bindable(vm).startDate,
                        in: ...vm.endDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "To"),
                        selection: Bindable(vm).endDate,
                        in: vm.startDate...,
                        displayedComponents: .date
                    )
                }
            } header: {
                Text(String(localized: "Date Range"))
            } footer: {
                Text(vm.useCustomDateRange
                     ? String(localized: "Only transactions within this range will be exported.")
                     : String(localized: "All transactions will be exported."))
                    .foregroundStyle(VColors.textSecondary)
            }

            // Export button
            Section {
                Button {
                    Task {
                        await vm.export()
                        if vm.exportURL != nil { showShareSheet = true }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isExporting {
                            ProgressView()
                                .tint(VColors.primary)
                        } else {
                            Label(String(localized: "Export & Share"), systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                    }
                }
                .disabled(vm.isExporting)
                .foregroundStyle(VColors.primary)
            }

            if let error = vm.error {
                Section {
                    HStack(spacing: VSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VColors.expense)
                        Text(error)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = vm.exportURL {
                ShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
    }
}
