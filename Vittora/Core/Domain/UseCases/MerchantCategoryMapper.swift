import Foundation
import VittoraCore

/// Files a card transaction under one of the user's own categories from its merchant
/// category code (MCC, ISO 18245), the four-digit code card networks give every merchant.
///
/// Used when a Wallet import meets a payee for the first time, so the payee has no usual
/// category yet. It only ever picks a category the user already has, matched by name;
/// it never creates one. Codes it does not know return nil and the transaction stays
/// uncategorised, which is recoverable; a confident wrong category is not.
enum MerchantCategoryMapper {
    /// Candidate category names, best first. The first names are the app's defaults.
    nonisolated static func candidateNames(forMCC code: Int) -> [String] {
        switch code {
        case 5411, 5422, 5441, 5451, 5462, 5499: ["Groceries", "Grocery", "Food"]
        case 5811...5814: ["Dining", "Restaurants", "Food & Dining", "Food"]
        case 4111, 4112, 4121, 4131, 4784, 4789, 7523: ["Transport", "Transportation"]
        case 5541, 5542, 5983: ["Fuel", "Gas", "Transport", "Transportation"]
        case 3000...3299, 3351...3441, 3501...3999, 4411, 4511, 4722, 7011, 7512: ["Travel", "Vacation"]
        case 4812, 4814: ["Phone", "Utilities", "Bills"]
        case 4816: ["Internet", "Utilities", "Bills"]
        case 4900: ["Utilities", "Bills"]
        case 4899, 5815...5818: ["Subscriptions", "Entertainment"]
        case 7832, 7841, 7922, 7929, 7932, 7933, 7941, 7991...7999: ["Entertainment", "Fun"]
        case 5912, 8011...8099: ["Health", "Medical", "Healthcare"]
        case 5611, 5621, 5631, 5641, 5651, 5655, 5661, 5681, 5691, 5697, 5698, 5699: ["Clothing", "Shopping"]
        case 5200, 5251, 5261, 5300...5399, 5712, 5719, 5722, 5732, 5733, 5734, 5941, 5942, 5943, 5945, 5947, 5999: ["Shopping"]
        case 8211, 8220, 8241, 8244, 8249, 8299: ["Education"]
        case 6300, 6381: ["Insurance"]
        case 7230, 7297, 7298: ["Personal Care", "Health"]
        case 742, 5995: ["Pets"]
        case 8398, 8661: ["Charity", "Donations", "Gifts"]
        case 6513: ["Rent", "Housing"]
        default: []
        }
    }

    /// The first candidate the user has as an expense category, matched ignoring case.
    nonisolated static func categoryID(forMCC code: Int?, in categories: [CategoryEntity]) -> UUID? {
        guard let code else { return nil }
        let expense = categories.filter { $0.type == .expense }
        for name in candidateNames(forMCC: code) {
            if let match = expense.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return match.id
            }
        }
        return nil
    }
}
