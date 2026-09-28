import Foundation
import SwiftData

/// Aliment ou plat enregistré par l'utilisateur pour être ressaisi rapidement.
@Model
final class SavedFood {
    var name: String = ""
    var brand: String?
    var unitRaw: String = "g"
    var referenceQuantity: Double = 100
    var defaultQuantity: Double = 100
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var alcohol: Double = 0
    var barcode: String?
    var useCount: Int = 0
    var lastUsed: Date = Date.now
    var createdAt: Date = Date.now

    init(template: FoodTemplate) {
        name = template.name
        brand = template.brand
        unitRaw = template.unit.rawValue
        referenceQuantity = template.referenceQuantity
        defaultQuantity = template.defaultQuantity
        barcode = template.barcode
        nutrients = template.nutrients
    }

    var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    /// Valeurs pour `referenceQuantity`.
    var nutrients: Nutrients {
        get {
            Nutrients(kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                      fiber: fiber, sugar: sugar, alcohol: alcohol)
        }
        set {
            kcal = newValue.kcal; protein = newValue.protein; carbs = newValue.carbs
            fat = newValue.fat; fiber = newValue.fiber; sugar = newValue.sugar
            alcohol = newValue.alcohol
        }
    }

    var template: FoodTemplate {
        FoodTemplate(name: name, brand: brand, unit: unit, referenceQuantity: referenceQuantity,
                     nutrients: nutrients, defaultQuantity: defaultQuantity, barcode: barcode,
                     source: .saved)
    }
}
