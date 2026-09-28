import Foundation

/// Aliment "candidat" (résultat de recherche, code-barre, estimation IA…) avant ajout au journal.
struct FoodTemplate: Identifiable, Hashable {
    enum Source: String {
        case saved, recent, database, openFoodFacts, ai, manual

        var label: String {
            switch self {
            case .saved: "Mes aliments"
            case .recent: "Récent"
            case .database: "Base intégrée"
            case .openFoodFacts: "Open Food Facts"
            case .ai: "Apple Intelligence"
            case .manual: "Saisie manuelle"
            }
        }
    }

    var id = UUID()
    var name: String
    var brand: String? = nil
    var unit: FoodUnit
    /// Les `nutrients` sont exprimés pour cette quantité (ex. 100 g, 1 portion).
    var referenceQuantity: Double
    var nutrients: Nutrients
    var defaultQuantity: Double
    var barcode: String? = nil
    var source: Source

    func nutrients(for quantity: Double) -> Nutrients {
        guard referenceQuantity > 0 else { return .zero }
        return nutrients.scaled(by: quantity / referenceQuantity)
    }

    var displayName: String {
        if let brand, !brand.isEmpty { return "\(name) · \(brand)" }
        return name
    }

    /// Texte court du type "250 kcal / 100 g".
    var densityLabel: String {
        let ref = unit == .portion
            ? (referenceQuantity == 1 ? "portion" : "\(referenceQuantity.formatted()) portions")
            : "\(referenceQuantity.formatted()) \(unit.rawValue)"
        return "\(Int(nutrients.kcal.rounded())) kcal / \(ref)"
    }
}

extension String {
    /// Normalisation pour la recherche : minuscules, sans accents.
    var searchKey: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
