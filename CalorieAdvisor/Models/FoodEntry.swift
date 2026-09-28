import Foundation
import SwiftData

/// Un aliment consommé. Les valeurs nutritionnelles sont stockées pour `refQuantity`
/// (ex. pour 100 g) afin de pouvoir modifier la quantité après coup.
@Model
final class FoodEntry {
    var timestamp: Date = Date.now
    var mealRaw: String = "lunch"
    var name: String = ""
    var brand: String?
    var quantity: Double = 100
    var unitRaw: String = "g"
    var refQuantity: Double = 100
    var refKcal: Double = 0
    var refProtein: Double = 0
    var refCarbs: Double = 0
    var refFat: Double = 0
    var refFiber: Double = 0
    var refSugar: Double = 0
    var refAlcohol: Double = 0
    var sourceRaw: String = "manual"
    var barcode: String?

    init(template: FoodTemplate, quantity: Double, meal: MealType, timestamp: Date) {
        self.timestamp = timestamp
        self.mealRaw = meal.rawValue
        self.name = template.name
        self.brand = template.brand
        self.quantity = quantity
        self.unitRaw = template.unit.rawValue
        self.refQuantity = template.referenceQuantity
        self.sourceRaw = template.source.rawValue
        self.barcode = template.barcode
        self.refNutrients = template.nutrients
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }

    var unit: FoodUnit {
        get { FoodUnit(rawValue: unitRaw) ?? .gram }
        set { unitRaw = newValue.rawValue }
    }

    var refNutrients: Nutrients {
        get {
            Nutrients(kcal: refKcal, protein: refProtein, carbs: refCarbs, fat: refFat,
                      fiber: refFiber, sugar: refSugar, alcohol: refAlcohol)
        }
        set {
            refKcal = newValue.kcal; refProtein = newValue.protein; refCarbs = newValue.carbs
            refFat = newValue.fat; refFiber = newValue.fiber; refSugar = newValue.sugar
            refAlcohol = newValue.alcohol
        }
    }

    /// Valeurs pour la quantité réellement consommée.
    var nutrients: Nutrients {
        guard refQuantity > 0 else { return .zero }
        return refNutrients.scaled(by: quantity / refQuantity)
    }

    /// Remplace les valeurs par des totaux saisis à la main pour la quantité actuelle.
    func overrideTotals(_ totals: Nutrients) {
        refQuantity = max(quantity, 0.0001)
        refNutrients = totals
    }

    var template: FoodTemplate {
        FoodTemplate(name: name, brand: brand, unit: unit, referenceQuantity: refQuantity,
                     nutrients: refNutrients, defaultQuantity: quantity, barcode: barcode,
                     source: .recent)
    }
}
