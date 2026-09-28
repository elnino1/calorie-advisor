import Foundation

/// Client minimal de l'API publique Open Food Facts (gratuite, sans clé).
enum OpenFoodFacts {
    private static let fields = "code,product_name,product_name_fr,brands,nutriments,serving_quantity,quantity"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "CalorieAdvisor/1.0 (usage personnel iOS)"]
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    static func product(barcode: String) async throws -> FoodTemplate? {
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ProductResponse.self, from: data)
        return response.product?.template(barcode: barcode)
    }

    static func search(_ query: String) async throws -> [FoodTemplate] {
        var components = URLComponents(string: "https://fr.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            .init(name: "search_terms", value: query),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: "20"),
            .init(name: "fields", value: fields),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.products.compactMap { $0.template(barcode: $0.code) }
    }

    // MARK: - Décodage

    private struct ProductResponse: Decodable { let product: Product? }
    private struct SearchResponse: Decodable { let products: [Product] }

    private struct Product: Decodable {
        let code: String?
        let product_name: String?
        let product_name_fr: String?
        let brands: String?
        let quantity: String?
        let serving_quantity: FlexibleDouble?
        let nutriments: Nutriments?

        func template(barcode: String?) -> FoodTemplate? {
            let name = [product_name_fr, product_name].compactMap { $0 }.first { !$0.isEmpty }
            guard let name, let n = nutriments else { return nil }
            let kcal = n.kcal?.value ?? n.energy?.value.map { $0 / 4.184 }
            guard let kcal else { return nil }
            let q = (quantity ?? "").lowercased()
            let isDrink = !q.contains("g") && (q.contains("ml") || q.contains("cl") || q.hasSuffix("l"))
            let serving = serving_quantity?.value ?? 0
            return FoodTemplate(
                name: name,
                brand: brands?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) },
                unit: isDrink ? .milliliter : .gram,
                referenceQuantity: 100,
                nutrients: Nutrients(kcal: kcal,
                                     protein: n.proteins?.value ?? 0,
                                     carbs: n.carbohydrates?.value ?? 0,
                                     fat: n.fat?.value ?? 0,
                                     fiber: n.fiber?.value ?? 0,
                                     sugar: n.sugars?.value ?? 0,
                                     alcohol: (n.alcohol?.value).map { Nutrients.alcoholGrams(volumeML: 100, abv: $0) } ?? 0),
                defaultQuantity: serving > 0 ? serving : 100,
                barcode: barcode,
                source: .openFoodFacts)
        }
    }

    private struct Nutriments: Decodable {
        let kcal: FlexibleDouble?
        let energy: FlexibleDouble?
        let proteins: FlexibleDouble?
        let carbohydrates: FlexibleDouble?
        let fat: FlexibleDouble?
        let fiber: FlexibleDouble?
        let sugars: FlexibleDouble?
        /// Open Food Facts exprime l'alcool en % vol.
        let alcohol: FlexibleDouble?

        enum CodingKeys: String, CodingKey {
            case kcal = "energy-kcal_100g"
            case energy = "energy_100g"
            case proteins = "proteins_100g"
            case carbohydrates = "carbohydrates_100g"
            case fat = "fat_100g"
            case fiber = "fiber_100g"
            case sugars = "sugars_100g"
            case alcohol = "alcohol_100g"
        }
    }

    /// Open Food Facts renvoie parfois des nombres sous forme de chaînes.
    private struct FlexibleDouble: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s.replacingOccurrences(of: ",", with: ".")) }
            else { value = nil }
        }
    }
}
