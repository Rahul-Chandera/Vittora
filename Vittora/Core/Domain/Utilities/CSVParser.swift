import Foundation

/// Minimal RFC-style CSV parser for bank export files (K5).
enum CSVParser {
    nonisolated static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var index = text.startIndex

        func appendField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func appendRowIfNeeded() {
            guard !currentRow.isEmpty || !currentField.isEmpty else { return }
            appendField()
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
            currentRow = []
        }

        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        currentField.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    currentField.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                appendField()
            } else if character == "\r" {
                appendRowIfNeeded()
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    index = next
                }
            } else if character == "\n" {
                appendRowIfNeeded()
            } else {
                currentField.append(character)
            }

            index = text.index(after: index)
        }

        appendRowIfNeeded()
        return rows
    }
}
