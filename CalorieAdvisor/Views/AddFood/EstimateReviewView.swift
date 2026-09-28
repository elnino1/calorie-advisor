import SwiftData
import SwiftUI

/// Vérification et ajustement des aliments estimés par l'IA avant ajout.
struct EstimateReviewView: View {
    let day: Date
    @Binding var meal: MealType
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var rows: [Row]

    struct Row: Identifiable {
        var template: FoodTemplate
        var quantity: Double
        var included = true
        var id: UUID { template.id }
        var nutrients: Nutrients { template.nutrients(for: quantity) }
    }

    init(items: [FoodTemplate], day: Date, meal: Binding<MealType>, onDone: @escaping () -> Void) {
        self.day = day
        _meal = meal
        self.onDone = onDone
        _rows = State(initialValue: items.map { Row(template: $0, quantity: $0.defaultQuantity) })
    }

    private var total: Nutrients { rows.filter(\.included).map(\.nutrients).total }

    var body: some View {
        List {
            Section {
                ForEach($rows) { $row in
                    HStack(alignment: .top) {
                        Button {
                            row.included.toggle()
                        } label: {
                            Image(systemName: row.included ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(row.included ? Color.accentColor : Color.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Nom", text: $row.template.name).font(.body.weight(.medium))
                            HStack {
                                TextField("Qté", value: $row.quantity, format: .number)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 70)
                                    .textFieldStyle(.roundedBorder)
                                Text(row.template.unit.label).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(row.nutrients.kcal.kcalText) kcal").monospacedDigit().bold()
                            }
                            Text("P \(row.nutrients.protein.gramsText) g · G \(row.nutrients.carbs.gramsText) g · L \(row.nutrients.fat.gramsText) g"
                                 + (row.nutrients.alcohol > 0 ? " · alcool \(row.nutrients.alcohol.gramsText) g" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .opacity(row.included ? 1 : 0.4)
                    }
                }
                .onDelete { rows.remove(atOffsets: $0) }
            } footer: {
                Text("Estimations approximatives : vérifiez les quantités. Les aliments reconnus dans la base intégrée utilisent ses valeurs de référence. Vous pourrez ajuster chaque entrée dans le journal.")
            }

            Section {
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Total", value: "\(total.kcal.kcalText) kcal")
            }
        }
        .navigationTitle("Vérifier")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                for row in rows where row.included && row.quantity > 0 {
                    FoodLogger.log(row.template, quantity: row.quantity, meal: meal, day: day, in: context)
                }
                onDone()
            } label: {
                Text("Ajouter \(rows.filter(\.included).count) élément(s) · \(total.kcal.kcalText) kcal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!rows.contains(where: \.included))
            .padding()
        }
    }
}
