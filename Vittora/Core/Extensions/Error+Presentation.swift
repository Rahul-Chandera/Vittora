import Foundation

extension Error {
    func userFacingMessage(fallback: String) -> String {
        let message = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, message != "(null)" else {
            return fallback
        }
        return message
    }
}
