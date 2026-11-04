import Foundation
import FoundationModels

// MARK: - Structures générées par le modèle

@Generable
struct AIFoodItem {
    @Guide(description: "Nom court de l'aliment ou de la boisson, en français, au singulier (ex. « Pâtes cuites », « Vin rouge »)")
    var name: String
    @Guide(description: "Quantité consommée estimée, en grammes pour un aliment ou en millilitres pour une boisson")
    var quantity: Double
    @Guide(description: "Vrai si c'est une boisson (quantité en millilitres)")
    var isDrink: Bool
    @Guide(description: "Calories (kcal) pour la quantité indiquée")
    var kcal: Double
    @Guide(description: "Protéines en grammes pour la quantité indiquée")
    var protein: Double
    @Guide(description: "Glucides en grammes pour la quantité indiquée")
    var carbs: Double
    @Guide(description: "Lipides en grammes pour la quantité indiquée")
    var fat: Double
    @Guide(description: "Fibres alimentaires en grammes pour la quantité indiquée")
    var fiber: Double
    @Guide(description: "Sucres en grammes pour la quantité indiquée (inclus dans les glucides)")
    var sugar: Double
    @Guide(description: "Grammes d'alcool pur pour la quantité indiquée, 0 si la boisson est sans alcool")
    var alcohol: Double
}

@Generable
struct AIMealEstimate {
    @Guide(description: "Chaque aliment ou boisson distinct du repas")
    var items: [AIFoodItem]
}

@Generable
struct AICoaching {
    @Guide(description: "Synthèse bienveillante de la période en 2 ou 3 phrases, avec des chiffres")
    var summary: String
    @Guide(description: "Un à trois points positifs")
    var positives: [String]
    @Guide(description: "Deux à quatre conseils concrets et réalisables pour les prochains jours")
    var suggestions: [String]
}

// MARK: - Service

/// Apple Intelligence via le framework Foundation Models : modèle exécuté sur l'appareil,
/// sans compte, sans clé d'API et sans envoi de données.
enum FoodIntelligence {
    enum Failure: LocalizedError {
        case unavailable(String)
        var errorDescription: String? {
            switch self { case .unavailable(let reason): reason }
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var statusText: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Disponible"
        case .unavailable(.deviceNotEligible):
            return "Appareil non compatible avec Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence est désactivé (Réglages > Apple Intelligence et Siri)"
        case .unavailable(.modelNotReady):
            return "Modèle en cours de téléchargement, réessayez plus tard"
        case .unavailable:
            return "Indisponible"
        }
    }

    private static let nutritionInstructions = """
        Tu es un nutritionniste français. Tu estimes les aliments, les portions et les valeurs nutritionnelles \
        d'un repas à partir d'une description. Utilise les valeurs de référence de la table CIQUAL. \
        Choisis des portions réalistes pour un adulte si la quantité n'est pas précisée. \
        Sépare les composants d'un plat quand c'est pertinent (ex. steak, frites, sauce) et n'oublie pas les boissons. \
        Pour une boisson alcoolisée, calcule l'alcool pur : volume (ml) × degré / 100 × 0,789.
        """

    /// Estime le contenu d'un repas décrit en texte libre, éventuellement accompagné
    /// des étiquettes détectées sur une photo.
    static func estimateMeal(description: String, photoLabels: [String] = []) async throws -> [FoodTemplate] {
        guard isAvailable else { throw Failure.unavailable(statusText) }

        var prompt = ""
        if !photoLabels.isEmpty {
            prompt += "Une photo du repas a été analysée ; éléments détectés (en anglais, du plus probable au moins probable) : "
            prompt += photoLabels.joined(separator: ", ") + ".\n"
            prompt += "L'assiette contient souvent plusieurs aliments : retiens chaque aliment plausible de cette liste, "
            prompt += "en regroupant les étiquettes qui désignent le même aliment (ex. « beef » et « steak ») "
            prompt += "et en ignorant celles qui ne sont pas des aliments.\n"
        }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            prompt += "Description de l'utilisateur (prioritaire sur la photo, chaque aliment cité doit figurer) : \(trimmed)\n"
        }
        prompt += "Liste les aliments et boissons consommés avec leurs quantités et valeurs nutritionnelles."

        let session = LanguageModelSession(instructions: nutritionInstructions)
        let response = try await session.respond(to: prompt, generating: AIMealEstimate.self)
        return response.content.items.compactMap(template(from:))
    }

    /// Convertit une estimation en aliment. Si l'aliment existe dans la base intégrée,
    /// on garde la quantité estimée mais on utilise les valeurs de référence (plus fiables).
    private static func template(from item: AIFoodItem) -> FoodTemplate? {
        let quantity = max(item.quantity, 0)
        guard quantity > 0, !item.name.isEmpty else { return nil }
        if var known = FoodDatabase.shared.exactMatch(item.name) {
            known.defaultQuantity = quantity
            known.source = .ai
            return known
        }
        var nutrients = Nutrients(kcal: max(item.kcal, 0), protein: max(item.protein, 0),
                                  carbs: max(item.carbs, 0), fat: max(item.fat, 0),
                                  fiber: max(item.fiber, 0), sugar: max(item.sugar, 0),
                                  alcohol: max(item.alcohol, 0))
        if nutrients.kcal == 0 { nutrients.kcal = nutrients.kcalFromMacros }
        return FoodTemplate(name: item.name, unit: item.isDrink ? .milliliter : .gram,
                            referenceQuantity: quantity, nutrients: nutrients,
                            defaultQuantity: quantity, source: .ai)
    }

    /// Analyse et conseils à partir d'un résumé chiffré de la période.
    static func coaching(context: String) async throws -> AICoaching {
        guard isAvailable else { throw Failure.unavailable(statusText) }
        let session = LanguageModelSession(instructions: """
            Tu es un coach nutrition bienveillant et factuel. Tu analyses le journal alimentaire et la \
            dépense énergétique d'une personne qui cherche à atteindre ses objectifs de santé ou de perte de poids. \
            Tiens compte aussi de l'hydratation par rapport à l'objectif, de la part de café ou thé et des boissons \
            sucrées ou alcoolisées. Appuie-toi uniquement sur les chiffres fournis. Réponds en français, tutoiement, sans jugement. \
            Ne donne pas de conseil médical ; recommande un professionnel de santé en cas de doute.
            """)
        let response = try await session.respond(to: context, generating: AICoaching.self)
        return response.content
    }
}
