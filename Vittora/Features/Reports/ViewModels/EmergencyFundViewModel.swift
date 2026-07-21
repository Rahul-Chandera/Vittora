import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class EmergencyFundViewModel {
    var snapshot: EmergencyFundSnapshot?
    var accounts: [AccountEntity] = []
    var selectedAccountIDs: Set<UUID> = []
    var isLoading = false
    var error: String?

    private let useCase: EmergencyFundUseCase
    private let selectionStore: any EmergencyFundAccountSelectionStoring

    init(
        useCase: EmergencyFundUseCase,
        selectionStore: any EmergencyFundAccountSelectionStoring
    ) {
        self.useCase = useCase
        self.selectionStore = selectionStore
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let report = try await useCase.execute(
                selectedAccountIDs: selectionStore.selectedAccountIDs
            )
            snapshot = report.snapshot
            accounts = report.eligibleAccounts
            selectedAccountIDs = report.selectedAccountIDs
            selectionStore.selectedAccountIDs = report.selectedAccountIDs
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load your emergency fund right now.")
            )
        }
        isLoading = false
    }

    func setAccount(_ accountID: UUID, selected: Bool) async {
        if selected {
            selectedAccountIDs.insert(accountID)
        } else {
            selectedAccountIDs.remove(accountID)
        }
        selectionStore.selectedAccountIDs = selectedAccountIDs
        await load()
    }
}
