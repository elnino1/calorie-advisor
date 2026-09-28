import SwiftData
import SwiftUI

/// Choix de la quantité avant ajout au journal.
struct PortionView: View {
    let template: FoodTemplate
    let day: Date
    @Binding var meal: MealType
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var quantity: Double
    @State private var saveToFavorites = false

    init(template: FoodTemplate, day: Date, meal: Binding<MealType>, onDone: @escaping () -> Void) {
        self.template = template
        self.day = day
        _meal = meal
        self.onDone = onDone
        _quantity = State(initialValue: template.defaultQuantity)
    }

    private var presets: [Double] {
        let base: [Double] = switch template.unit {
        case .gram: [30, 50, 100, 150, 200, 300]
        case .milliliter: [40, 125, 250, 330, 500]
        case .portion: [0.5, 1, 1.5, 2]
        }
        return Array(Set(base + [template.defaultQuantity])).sorted()
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.headline)
                    if let brand = template.brand { Text(brand).foregroundStyle(.secondary) }
                    Text("\(template.densityLabel) · \(template.source.label)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Quantité") {
                HStack {
                    TextField("Quantité", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                    Text(template.unit.label).foregroundStyle(.secondary)
                    Stepper("", value: $quantity, in: 0...5000, step: template.unit == .portion ? 0.5 : 10)
                        .labelsHidden()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.self) { value in
                            Button("\(value.formatted()) \(template.unit == .portion ? "" : template.unit.rawValue)") {
                                quantity = value
                            }
                            .buttonStyle(.bordered)
                            .tint(value == quantity ? Color.accentColor : Color.secondary)
                        }
                    }
                }
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Valeurs pour cette quantité") {
                NutrientSummary(nutrients: template.nutrients(for: quantity))
            }

            if template.source != .saved {
                Section {
                    Toggle("Ajouter à mes aliments", isOn: $saveToFavorites)
                }
            }
        }
        .navigationTitle("Portion")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                FoodLogger.log(template, quantity: quantity, meal: meal, day: day,
                               saveToFavorites: saveToFavorites, in: context)
                onDone()
            } label: {
                Text("Ajouter · \(template.nutrients(for: quantity).kcal.kcalText) kcal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(quantity <= 0)
            .padding()
        }
    }
}
