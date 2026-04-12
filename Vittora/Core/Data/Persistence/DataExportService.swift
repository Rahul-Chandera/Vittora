import Foundation

protocol DataExportServiceProtocol: Sendable {
    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL
}

@MainActor
final class DataExportService: DataExportServiceProtocol, Sendable {
    private let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func exportTransactionsCSV(filter: TransactionFilter?) async throws -> URL {
        let transactions = try await transactionRepository.fetchAll(filter: filter)

        var csvContent = "Date,Amount,Category,Account,Payee,Type,Notes,Tags\n"

        for transaction in transactions {
            let dateFormatter = ISO8601DateFormatter()
            let dateString = dateFormatter.string(from: transaction.date)

            let category = transaction.categoryID?.uuidString ?? ""
            let account = transaction.accountID?.uuidString ?? ""
            let payee = transaction.payeeID?.uuidString ?? ""
            let note = (transaction.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let tagsString = transaction.tags.joined(separator: ";")

            let csvLine = """
            "\(dateString)","\(transaction.amount)","\(category)","\(account)","\(payee)","\(transaction.type.rawValue)","\(note)","\(tagsString)"
            """

            csvContent += csvLine + "\n"
        }

        let fileName = "vittora_transactions_\(UUID().uuidString).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            throw VittoraError.exportFailed(
                String(localized: "Failed to create CSV file: \(error.localizedDescription)")
            )
        }
    }
}
