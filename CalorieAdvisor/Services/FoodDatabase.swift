import Foundation

/// Petite base d'aliments courants embarquée (valeurs approximatives de type CIQUAL),
/// utilisée hors-ligne pour l'auto-complétion et pour fiabiliser les estimations IA.
final class FoodDatabase {
    static let shared = FoodDatabase()

    private struct Row: Decodable {
        let n: String, u: String
        let k: Double, p: Double, c: Double, f: Double, fi: Double, s: Double, a: Double
        let d: Double
    }

    private(set) var foods: [FoodTemplate] = []
    private var keys: [String] = []

    private init() {
        guard let url = Bundle.main.url(forResource: "foods_fr", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data) else { return }
        foods = rows.map { r in
            let unit = FoodUnit(rawValue: r.u) ?? .gram
            return FoodTemplate(name: r.n, unit: unit, referenceQuantity: 100,
                                nutrients: Nutrients(kcal: r.k, protein: r.p, carbs: r.c, fat: r.f,
                                                     fiber: r.fi, sugar: r.s, alcohol: r.a),
                                defaultQuantity: r.d, source: .database)
        }
        keys = foods.map(\.name.searchKey)
    }

    /// Recherche : les noms qui commencent par la requête d'abord, puis ceux qui contiennent tous les mots.
    func search(_ query: String, limit: Int = 15) -> [FoodTemplate] {
        let q = query.searchKey
        guard !q.isEmpty else { return [] }
        let words = q.split(separator: " ").map(String.init)
        var prefix: [FoodTemplate] = [], contains: [FoodTemplate] = []
        for (i, key) in keys.enumerated() {
            if key.hasPrefix(q) { prefix.append(foods[i]) }
            else if words.allSatisfy({ key.contains($0) }) { contains.append(foods[i]) }
        }
        return Array((prefix + contains).prefix(limit))
    }

    /// Correspondance stricte (nom identique, au pluriel près) pour remplacer une estimation IA.
    func exactMatch(_ name: String) -> FoodTemplate? {
        let q = name.searchKey
        let singular = q.hasSuffix("s") ? String(q.dropLast()) : q
        guard let i = keys.firstIndex(where: { $0 == q || $0 == singular || $0 == q + "s" }) else { return nil }
        return foods[i]
    }
}
