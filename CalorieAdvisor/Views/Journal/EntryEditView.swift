import SwiftData
import SwiftUI

/// Modification d'une entrée : quantité, repas, heure, ou ajustement manuel des valeurs.
struct EntryEditView: View {
    @Bindable var entry: FoodEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var manual = false
    @State private var totals = Nutrients.zero

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom", text: $entry.name)
                    HStack {
                        Text("Quantité")
                        Spacer()
                        TextField("Quantité", value: $entry.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text(entry.unit.label).foregroundStyle(.secondary)
                    }
                    Picker("Repas", selection: $entry.meal) {
                        ForEach(MealType.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Heure", selection: $entry.timestamp)
                }

                Section {
                    Toggle("Ajuster les valeurs manuellement", isOn: $manual)
                    if manual {
                        NutrientFields(nutrients: $totals)
                        Button("Appliquer") {
                            entry.overrideTotals(totals)
                            manual = false
                        }
                    } else {
                        NutrientSummary(nutrients: entry.nutrients)
                    }
                } header: {
                    Text("Valeurs pour \(entry.quantity.gramsText) \(entry.unit.label)")
                }

                Section {
                    Button("Supprimer", role: .destructive) {
                        context.delete(entry)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .onChange(of: manual) { _, isOn in
                if isOn { totals = entry.nutrients }
            }
        }
    }
}

/// Saisie des valeurs nutritionnelles.
struct NutrientFields: View {
    @Binding var nutrients: Nutrients

    var body: some View {
        row("Calories", "kcal", $nutrients.kcal)
        row("Protéines", "g", $nutrients.protein)
        row("Glucides", "g", $nutrients.carbs)
        row("dont sucres", "g", $nutrients.sugar)
        row("Lipides", "g", $nutrients.fat)
        row("Fibres", "g", $nutrients.fiber)
        row("Alcool pur", "g", $nutrients.alcohol)
    }

    private func row(_ title: String, _ unit: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
        }
    }
}

/// Affichage des valeurs nutritionnelles.
struct NutrientSummary: View {
    let nutrients: Nutrients

    var body: some View {
        LabeledContent("Calories", value: "\(nutrients.kcal.kcalText) kcal")
        LabeledContent("Protéines", value: "\(nutrients.protein.gramsText) g")
        LabeledContent("Glucides", value: "\(nutrients.carbs.gramsText) g (sucres \(nutrients.sugar.gramsText) g)")
        LabeledContent("Lipides", value: "\(nutrients.fat.gramsText) g")
        if nutrients.fiber > 0 { LabeledContent("Fibres", value: "\(nutrients.fiber.gramsText) g") }
        if nutrients.alcohol > 0 { LabeledContent("Alcool pur", value: "\(nutrients.alcohol.gramsText) g") }
    }
}
