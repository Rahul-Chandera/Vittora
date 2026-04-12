import Foundation

extension String {
    /// Check if string is a valid email address.
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    /// Check if string is a valid phone number (basic validation).
    /// Accepts formats: 1234567890, (123) 456-7890, 123-456-7890, +1 123 456 7890
    var isValidPhone: Bool {
        let phoneRegex = "^[+]?[(]?[0-9]{3}[)]?[-\\s\\.]?[0-9]{3}[-\\s\\.]?[0-9]{4,6}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }

    /// Check if string is a valid URL.
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }

    /// Check if string contains only alphabetic characters.
    var isAlphabetic: Bool {
        return !self.isEmpty && self.allSatisfy { $0.isLetter }
    }

    /// Check if string contains only numeric characters.
    var isNumeric: Bool {
        return !self.isEmpty && self.allSatisfy { $0.isNumber }
    }

    /// Check if string is alphanumeric.
    var isAlphanumeric: Bool {
        return !self.isEmpty && self.allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// Remove leading and trailing whitespace.
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespaces)
    }

    /// Check if string is empty after trimming whitespace.
    var isTrimmedEmpty: Bool {
        return self.trimmed.isEmpty
    }

    /// Remove all whitespace.
    var withoutWhitespace: String {
        return self.replacingOccurrences(of: " ", with: "")
    }

    /// Capitalize first letter of string.
    var capitalizingFirstLetter: String {
        return prefix(1).uppercased() + dropFirst()
    }

    /// Get character count excluding whitespace.
    var countWithoutWhitespace: Int {
        return self.withoutWhitespace.count
    }

    /// Check if string meets minimum length requirement.
    ///
    /// - Parameter length: Minimum required length
    /// - Returns: True if string length >= required length
    func meetsMinimumLength(_ length: Int) -> Bool {
        return self.count >= length
    }

    /// Check if string exceeds maximum length.
    ///
    /// - Parameter length: Maximum allowed length
    /// - Returns: True if string length <= allowed length
    func meetsMaximumLength(_ length: Int) -> Bool {
        return self.count <= length
    }

    /// Check if string has specific length range.
    ///
    /// - Parameters:
    ///   - minLength: Minimum length
    ///   - maxLength: Maximum length
    /// - Returns: True if string is within range
    func meetsLengthRequirement(min minLength: Int, max maxLength: Int) -> Bool {
        return self.count >= minLength && self.count <= maxLength
    }

    /// Validate password strength.
    ///
    /// Requirements:
    /// - At least 8 characters
    /// - Contains uppercase letter
    /// - Contains lowercase letter
    /// - Contains number
    /// - Contains special character
    var isStrongPassword: Bool {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: self)
    }

    /// Validate as international phone number format.
    var isValidInternationalPhone: Bool {
        let phoneRegex = "^[+]?[0-9\\s()\\-]{7,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }

    /// Check if string contains special characters.
    var containsSpecialCharacters: Bool {
        let specialCharacterSet = CharacterSet(charactersIn: "@$!%*?&")
        return self.rangeOfCharacter(from: specialCharacterSet) != nil
    }

    /// Truncate string to specified length with ellipsis.
    ///
    /// - Parameters:
    ///   - length: Maximum length before truncation
    ///   - suffix: Suffix to append (default: "...")
    /// - Returns: Truncated string
    func truncated(to length: Int, suffix: String = "...") -> String {
        guard self.count > length else { return self }
        return String(self.prefix(max(0, length - suffix.count))) + suffix
    }

    /// Replace multiple consecutive spaces with single space.
    var normalizeSpaces: String {
        let components = self.components(separatedBy: .whitespaces)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
