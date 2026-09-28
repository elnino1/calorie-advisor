import SwiftData
import SwiftUI

/// Saisie libre d'un aliment ou d'une boisson (valeurs pour la quantité consommée).
struct ManualEntryView: View {
    let day: Date
    @Binding var meal: MealType
    let barcode: String?
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var unit: FoodUnit = .gram
    @State private var quantity: Double = 100
    @State private var totals = Nutrients.zero
    @State private var abv: Double = 0
    @State private var saveToFavorites = true

    init(day: Date, meal: Binding<MealType>, name: String = "", barcode: String? = nil,
         onDone: @escaping () -> Void) {
        self.day = day
        _meal = meal
        self.barcode = barcode
        self.onDone = onDone
        _name = State(initialValue: name)
    }

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $name)
                Picker("Unité", selection: $unit) {
                    ForEach(FoodUnit.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Quantité")
                    Spacer()
                    TextField("Quantité", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(unit.label).foregroundStyle(.secondary)
                }
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
                if let barcode {
                    LabeledContent("Code-barre", value: barcode)
                }
            }

            if unit == .milliliter {
                Section {
                    HStack {
                        Text("Degré d'alcool")
                        Spacer()
                        TextField("0", value: $abv, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("% vol").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("L'alcool pur et ses calories (7 kcal/g) sont calculés automatiquement ; ajoutez les glucides (sucres) si besoin.")
                }
            }

            Section("Valeurs pour \(quantity.formatted()) \(unit.label)") {
                NutrientFields(nutrients: $totals)
                Button("Calculer les calories à partir des macros") {
                    totals.kcal = totals.kcalFromMacros
                }
                .font(.footnote)
            }

            Section {
                Toggle("Ajouter à mes aliments", isOn: $saveToFavorites)
            }
        }
        .navigationTitle("Saisie manuelle")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: abv) { updateAlcohol() }
        .onChange(of: quantity) { if abv > 0 { updateAlcohol() } }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || quantity <= 0)
            }
        }
    }

    private func updateAlcohol() {
        totals.alcohol = Nutrients.alcoholGrams(volumeML: quantity, abv: abv)
        totals.kcal = totals.kcalFromMacros
    }

    private func save() {
        var template = FoodTemplate(name: name.trimmingCharacters(in: .whitespaces), unit: unit,
                                    referenceQuantity: quantity, nutrients: totals,
                                    defaultQuantity: quantity, barcode: barcode, source: .manual)
        // Normalise pour 100 g/ml afin que l'aliment enregistré soit facilement réutilisable.
        if unit != .portion, quantity > 0 {
            template.nutrients = totals.scaled(by: 100 / quantity)
            template.referenceQuantity = 100
        }
        FoodLogger.log(template, quantity: quantity, meal: meal, day: day,
                       saveToFavorites: saveToFavorites, in: context)
        onDone()
    }
}
