import SwiftUI

/// Description en langage naturel ("2 croissants et un café au lait") estimée par Apple Intelligence.
struct DescribeMealView: View {
    let day: Date
    @Binding var meal: MealType
    let onDone: () -> Void

    @State private var text: String
    @State private var estimating = false
    @State private var estimate: EstimateBox?
    @State private var error: String?

    init(day: Date, meal: Binding<MealType>, initialText: String = "", onDone: @escaping () -> Void) {
        self.day = day
        _meal = meal
        self.onDone = onDone
        _text = State(initialValue: initialText)
    }

    var body: some View {
        Form {
            Section {
                TextField("Ex. : une entrecôte frites avec une salade, 2 verres de bordeaux et un café",
                          text: $text, axis: .vertical)
                    .lineLimit(3...8)
            } footer: {
                Text("Indiquez les quantités si possible (grammes, verres, cuillères…).")
            }

            Section {
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        if estimating { ProgressView() }
                        Label("Estimer avec Apple Intelligence", systemImage: "sparkles")
                    }
                }
                .disabled(estimating || text.trimmingCharacters(in: .whitespaces).isEmpty
                          || !FoodIntelligence.isAvailable)
                if !FoodIntelligence.isAvailable {
                    Text(FoodIntelligence.statusText).font(.footnote).foregroundStyle(.secondary)
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Décrire le repas")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $estimate) { box in
            EstimateReviewView(items: box.items, day: day, meal: $meal, onDone: onDone)
        }
    }

    private func run() async {
        estimating = true
        error = nil
        defer { estimating = false }
        do {
            let items = try await FoodIntelligence.estimateMeal(description: text)
            if items.isEmpty { error = "Aucun aliment identifié." }
            else { estimate = EstimateBox(items: items) }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
