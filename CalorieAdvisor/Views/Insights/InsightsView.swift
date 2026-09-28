import SwiftData
import SwiftUI

/// Synthèse et conseils générés par Apple Intelligence à partir des 7 derniers jours.
struct InsightsView: View {
    @Environment(EnergyStore.self) private var energyStore
    @Environment(\.modelContext) private var context
    private var goal = CalorieGoal()
    private var targetDeficit: Double { goal.dailyDeficit(latestWeight: energyStore.latestWeight) }

    @State private var coaching: AICoaching?
    @State private var loading = false
    @State private var error: String?
    @State private var promptPreview = ""

    var body: some View {
        NavigationStack {
            List {
                if !FoodIntelligence.isAvailable {
                    Section {
                        Label(FoodIntelligence.statusText, systemImage: "exclamationmark.triangle")
                    }
                }

                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            Label(coaching == nil ? "Analyser mes 7 derniers jours" : "Actualiser l'analyse",
                                  systemImage: "sparkles")
                            if loading { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(loading || !FoodIntelligence.isAvailable)
                } footer: {
                    Text("L'analyse est réalisée sur l'iPhone par Apple Intelligence ; aucune donnée ne quitte l'appareil.")
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }

                if let coaching {
                    Section("Synthèse") {
                        Text(coaching.summary)
                    }
                    if !coaching.positives.isEmpty {
                        Section("Points positifs") {
                            ForEach(coaching.positives, id: \.self) { Label($0, systemImage: "hand.thumbsup") }
                        }
                    }
                    if !coaching.suggestions.isEmpty {
                        Section("Conseils") {
                            ForEach(coaching.suggestions, id: \.self) { Label($0, systemImage: "lightbulb") }
                        }
                    }
                    Section {
                        DisclosureGroup("Données transmises au modèle") {
                            Text(promptPreview).font(.caption.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Conseils")
        }
    }

    private func generate() async {
        loading = true
        error = nil
        defer { loading = false }
        let context = await buildContext()
        promptPreview = context
        do {
            coaching = try await FoodIntelligence.coaching(context: context)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Résumé compact (le modèle embarqué a une fenêtre de contexte limitée).
    private func buildContext() async -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -7, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let entries = FoodLogger.entries(from: start, to: tomorrow, in: self.context)
        let energy = await energyStore.energy(from: start, through: today)
        let stats = DayStats.build(entries: entries, energy: energy)
        let profile = UserProfile.load()

        var lines = ["Profil : \(profile.isMale ? "homme" : "femme"), \(profile.age) ans, \(Int(profile.heightCm)) cm, \(Int(energyStore.latestWeight ?? profile.weightKg)) kg. Objectif calorique : \(CalorieGoal.label(for: targetDeficit)) par jour."]
        if let plan = goal.plan(latestWeight: energyStore.latestWeight) {
            lines.append("Poids cible : \(plan.targetKg.formatted()) kg. \(plan.summary)")
        }
        let hydrationTarget = HydrationGoal.current(latestWeight: energyStore.latestWeight)
        lines.append("Objectif d'hydratation : \(Int(hydrationTarget)) ml/jour de boissons sans alcool.")
        lines.append("Jours (apport kcal / dépense kcal / balance ; protéines, glucides, lipides, alcool en g ; boissons en ml) :")
        let formatter = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        for s in stats {
            let label = calendar.isDateInToday(s.day) ? "aujourd'hui (en cours)" : s.day.formatted(formatter)
            let n = s.intake
            let burned = s.energy.map { "\(Int($0.total))" } ?? "?"
            let balance = s.balance.map { String(format: "%+d", Int($0)) } ?? "?"
            let h = s.hydration
            lines.append("- \(label) : \(Int(n.kcal)) / \(burned) / \(balance) ; P\(Int(n.protein)) G\(Int(n.carbs)) L\(Int(n.fat)) A\(Int(n.alcohol)) ; boissons \(Int(h.hydrating)) (eau \(Int(h.volume(.water))), café/thé \(Int(h.volume(.hot))), autres \(Int(h.volume(.other))), alcool \(Int(h.volume(.alcohol))))")
        }

        // Aliments les plus caloriques de la période.
        let byName = Dictionary(grouping: entries, by: \.name)
            .mapValues { $0.map(\.nutrients.kcal).reduce(0, +) }
            .sorted { $0.value > $1.value }
            .prefix(8)
        if !byName.isEmpty {
            lines.append("Principales sources de calories : " + byName.map { "\($0.key) (\(Int($0.value)) kcal)" }.joined(separator: ", "))
        }
        let drinks = entries.filter { $0.nutrients.alcohol > 0 }
        if !drinks.isEmpty {
            let alcohol = drinks.map(\.nutrients.alcohol).reduce(0, +)
            lines.append("Alcool sur la période : \(Int(alcohol)) g, soit \(Int(alcohol * 7)) kcal.")
        }
        return lines.joined(separator: "\n")
    }
}
