import SwiftData
import SwiftUI

/// Écrans d'ajout accessibles depuis la recherche.
enum AddMode: Hashable {
    case scanner, photo, describe, manual(barcode: String?)
}

/// Recherche avec auto-complétion (mes aliments, récents, base intégrée, Open Food Facts)
/// et accès aux autres modes d'ajout.
struct AddFoodView: View {
    let day: Date
    @State private var meal: MealType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedFood.useCount, order: .reverse) private var saved: [SavedFood]

    @State private var query = ""
    @State private var path = NavigationPath()
    @State private var recents: [FoodTemplate] = []
    @State private var remote: [FoodTemplate] = []
    @State private var remoteLoading = false
    @State private var remoteFailed = false

    init(day: Date, meal: MealType) {
        self.day = day
        _meal = State(initialValue: meal)
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmedQuery.isEmpty {
                    Section { actions }
                    section("Mes aliments et plats", saved.prefix(15).map(\.template))
                    section("Récents", recents.prefix(20))
                } else {
                    let key = trimmedQuery.searchKey
                    section("Mes aliments et plats", saved.map(\.template).filter { $0.name.searchKey.contains(key) })
                    section("Récents", recents.filter { $0.name.searchKey.contains(key) })
                    section("Base intégrée", FoodDatabase.shared.search(trimmedQuery))
                    remoteSection
                    Section {
                        NavigationLink(value: AddMode.describe) {
                            Label("Estimer « \(trimmedQuery) » avec Apple Intelligence", systemImage: "sparkles")
                        }
                        NavigationLink(value: AddMode.manual(barcode: nil)) {
                            Label("Saisie manuelle", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Rechercher un aliment, une boisson…")
            .autocorrectionDisabled()
            .navigationTitle("Ajouter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Picker("Repas", selection: $meal) {
                        ForEach(MealType.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationDestination(for: FoodTemplate.self) { template in
                PortionView(template: template, day: day, meal: $meal, onDone: { dismiss() })
            }
            .navigationDestination(for: AddMode.self) { mode in
                switch mode {
                case .scanner:
                    BarcodeScanView(day: day, meal: $meal, onDone: { dismiss() })
                case .photo:
                    PhotoEntryView(day: day, meal: $meal, onDone: { dismiss() })
                case .describe:
                    DescribeMealView(day: day, meal: $meal, initialText: trimmedQuery, onDone: { dismiss() })
                case .manual(let barcode):
                    ManualEntryView(day: day, meal: $meal, name: trimmedQuery, barcode: barcode,
                                    onDone: { dismiss() })
                }
            }
            .task { loadRecents() }
            .task(id: trimmedQuery) { await searchRemote() }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            action("Code-barre", "barcode.viewfinder", .scanner)
            action("Photo", "camera", .photo)
            action("Décrire", "sparkles", .describe)
            action("Manuel", "square.and.pencil", .manual(barcode: nil))
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    /// Boutons indépendants (et non des NavigationLink) : plusieurs liens dans une même ligne
    /// de liste s'activeraient tous ensemble et empileraient les écrans.
    private func action(_ title: String, _ symbol: String, _ mode: AddMode) -> some View {
        Button {
            path.append(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.tint)
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func section<S: Sequence>(_ title: String, _ items: S) -> some View where S.Element == FoodTemplate {
        let list = Array(items)
        if !list.isEmpty {
            Section(title) {
                ForEach(list) { template in
                    NavigationLink(value: template) { TemplateRow(template: template) }
                }
            }
        }
    }

    @ViewBuilder
    private var remoteSection: some View {
        if remoteLoading {
            Section("Open Food Facts") {
                HStack { ProgressView(); Text("Recherche…").foregroundStyle(.secondary) }
            }
        } else if remoteFailed {
            Section("Open Food Facts") {
                Text("Recherche en ligne indisponible").foregroundStyle(.secondary)
            }
        } else {
            section("Open Food Facts", remote)
        }
    }

    private func loadRecents() {
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 400
        let entries = (try? context.fetch(descriptor)) ?? []
        let savedNames = Set(saved.map(\.name.searchKey))
        var seen = Set<String>()
        recents = entries.compactMap { entry in
            let key = entry.name.searchKey
            guard !savedNames.contains(key), seen.insert(key).inserted else { return nil }
            return entry.template
        }
    }

    private func searchRemote() async {
        remote = []
        remoteFailed = false
        let q = trimmedQuery
        guard q.count >= 3 else { return }
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        remoteLoading = true
        defer { remoteLoading = false }
        do {
            let results = try await OpenFoodFacts.search(q)
            if !Task.isCancelled { remote = results }
        } catch {
            if !Task.isCancelled { remoteFailed = true }
        }
    }
}

struct TemplateRow: View {
    let template: FoodTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(template.displayName).lineLimit(2)
            HStack(spacing: 6) {
                Text(template.densityLabel)
                if template.nutrients.alcohol > 0 {
                    Image(systemName: "wineglass").imageScale(.small)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
