import Foundation
import SwiftData

/// Opérations d'écriture communes sur le journal.
@MainActor
enum FoodLogger {
    /// Date d'enregistrement : maintenant si c'est aujourd'hui, sinon l'heure typique du repas.
    static func timestamp(for day: Date, meal: MealType) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return .now }
        return calendar.date(bySettingHour: meal.typicalHour, minute: 0, second: 0, of: day) ?? day
    }

    @discardableResult
    static func log(_ template: FoodTemplate, quantity: Double, meal: MealType, day: Date,
                    saveToFavorites: Bool = false, in context: ModelContext) -> FoodEntry {
        // Les boissons vont toujours dans la section Boissons ; un aliment ajouté depuis
        // cette section rejoint le repas correspondant à l'heure.
        var meal = meal
        if template.isDrink {
            meal = .drinks
        } else if meal == .drinks {
            meal = Calendar.current.isDateInToday(day) ? .suggested() : .snack
        }
        let entry = FoodEntry(template: template, quantity: quantity, meal: meal,
                              timestamp: timestamp(for: day, meal: meal))
        context.insert(entry)

        if let saved = savedFood(matching: template, in: context) {
            saved.useCount += 1
            saved.lastUsed = .now
            saved.defaultQuantity = quantity
        } else if saveToFavorites {
            var t = template
            t.defaultQuantity = quantity
            let saved = SavedFood(template: t)
            saved.useCount = 1
            context.insert(saved)
        }
        return entry
    }

    static func savedFood(matching template: FoodTemplate, in context: ModelContext) -> SavedFood? {
        let name = template.name
        let descriptor = FetchDescriptor<SavedFood>(predicate: #Predicate { $0.name == name })
        if let match = try? context.fetch(descriptor).first { return match }
        if template.barcode != nil {
            let code: String? = template.barcode
            let byCode = FetchDescriptor<SavedFood>(predicate: #Predicate { $0.barcode == code })
            return try? context.fetch(byCode).first
        }
        return nil
    }

    /// Enregistre tous les aliments d'un repas comme un "plat" réutilisable (1 portion = le repas entier).
    static func saveMealAsDish(named name: String, entries: [FoodEntry], in context: ModelContext) {
        let total = entries.map(\.nutrients).total
        let template = FoodTemplate(name: name, unit: .portion, referenceQuantity: 1, nutrients: total,
                                    defaultQuantity: 1, source: .saved)
        context.insert(SavedFood(template: template))
    }

    static func entries(from start: Date, to end: Date, in context: ModelContext) -> [FoodEntry] {
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
