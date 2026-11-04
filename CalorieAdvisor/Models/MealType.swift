import Foundation

nonisolated enum MealType: String, CaseIterable, Identifiable, Codable, Sendable {
    case breakfast, lunch, snack, dinner, drinks

    /// Les repas proprement dits (sans la section Boissons).
    static let meals: [MealType] = [.breakfast, .lunch, .snack, .dinner]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Petit-déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Collation"
        case .dinner: "Dîner"
        case .drinks: "Boissons"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .snack: "carrot"
        case .dinner: "moon.stars"
        case .drinks: "cup.and.saucer"
        }
    }

    /// Heure utilisée quand on saisit un repas pour un jour passé.
    var typicalHour: Int {
        switch self {
        case .breakfast: 8
        case .lunch: 12
        case .snack: 16
        case .dinner: 20
        case .drinks: 12
        }
    }

    static func suggested(for date: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 15..<18: .snack
        default: .dinner
        }
    }
}

nonisolated enum FoodUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case gram = "g"
    case milliliter = "ml"
    case portion = "portion"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gram: "g"
        case .milliliter: "ml"
        case .portion: "portion(s)"
        }
    }

    /// Quantité de référence habituelle pour exprimer les valeurs nutritionnelles.
    var defaultReference: Double { self == .portion ? 1 : 100 }
}
