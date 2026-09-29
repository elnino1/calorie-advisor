import SwiftData
import SwiftUI

struct JournalView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    /// Jour courant, mis à jour au passage de minuit et au retour au premier plan : SwiftUI ne
    /// redessine pas la vue d'elle-même quand la date change (app restée ouverte en arrière-plan).
    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var addingMeal: MealType?
    @Environment(\.scenePhase) private var scenePhase

    private var isToday: Bool { day >= today }

    var body: some View {
        NavigationStack {
            DayJournal(day: day, onAdd: { addingMeal = $0 })
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    }
                    ToolbarItem(placement: .principal) {
                        DatePicker("Jour", selection: $day, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(isToday)
                    }
                }
                .sheet(item: $addingMeal) { meal in
                    AddFoodView(day: day, meal: meal)
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                    .receive(on: RunLoop.main)) { _ in refreshToday() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { refreshToday() }
                }
        }
    }

    /// Passe au nouveau jour si le journal affichait « aujourd'hui » ; un jour passé consulté reste affiché.
    private func refreshToday() {
        let now = Calendar.current.startOfDay(for: .now)
        guard now != today else { return }
        if day == today { day = now }
        today = now
    }

    private var title: String {
        isToday ? "Aujourd'hui" : day.formatted(.dateTime.weekday(.wide).day().month())
    }

    private func shift(_ days: Int) {
        refreshToday()
        let calendar = Calendar.current
        guard let next = calendar.date(byAdding: .day, value: days, to: day), next <= today else { return }
        day = calendar.startOfDay(for: next)
    }
}

/// Contenu d'une journée : synthèse + repas.
private struct DayJournal: View {
    let day: Date
    let onAdd: (MealType) -> Void

    @Environment(EnergyStore.self) private var energyStore
    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @State private var energy: DayEnergy?
    @State private var editing: FoodEntry?
    @State private var dishToSave: MealType?
    @State private var dishName = ""
    /// Sections repliées (valeurs brutes de MealType séparées par des virgules), mémorisé entre les lancements.
    @AppStorage("journal.collapsedSections") private var collapsedRaw = ""

    init(day: Date, onAdd: @escaping (MealType) -> Void) {
        self.day = day
        self.onAdd = onAdd
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _entries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= start && $0.timestamp < end },
                         sort: \FoodEntry.timestamp)
    }

    var body: some View {
        List {
            Section {
                DaySummaryCard(intake: entries.map(\.nutrients).total, energy: energy,
                               isToday: Calendar.current.isDateInToday(day))
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if !entries.isEmpty {
                Section {
                    DietScoreCard(entries: entries, isToday: Calendar.current.isDateInToday(day))
                }
            }

            ForEach(MealType.meals) { meal in
                mealSection(meal)
            }
            mealSection(.drinks)
        }
        .listSectionSpacing(12)
        .refreshable { await loadEnergy() }
        .task(id: day) { await loadEnergy() }
        .onChange(of: energyStore.revision) { Task { await loadEnergy() } }
        .sheet(item: $editing) { entry in
            EntryEditView(entry: entry)
        }
        .alert("Enregistrer comme plat", isPresented: Binding(get: { dishToSave != nil },
                                                               set: { if !$0 { dishToSave = nil } })) {
            TextField("Nom du plat", text: $dishName)
            Button("Enregistrer") {
                if let meal = dishToSave, !dishName.isEmpty {
                    FoodLogger.saveMealAsDish(named: dishName, entries: entries.filter { $0.journalSection == meal },
                                              in: context)
                }
                dishToSave = nil
            }
            Button("Annuler", role: .cancel) { dishToSave = nil }
        } message: {
            Text("Le repas entier deviendra une portion réutilisable dans « Mes aliments ».")
        }
    }

    private var collapsed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func toggleCollapsed(_ meal: MealType) {
        var set = collapsed
        if set.contains(meal.rawValue) { set.remove(meal.rawValue) } else { set.insert(meal.rawValue) }
        withAnimation { collapsedRaw = set.sorted().joined(separator: ",") }
    }

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let items = entries.filter { $0.journalSection == meal }
        let isCollapsed = collapsed.contains(meal.rawValue)
        Section {
            if meal == .drinks {
                HydrationCard(entries: items, day: day)
            }
            if !isCollapsed {
                ForEach(items) { entry in
                    Button { editing = entry } label: { EntryRow(entry: entry) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(items[index]) }
                }
            }
            Button {
                onAdd(meal)
            } label: {
                Label("Ajouter", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Button {
                    toggleCollapsed(meal)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        Label(meal.title, systemImage: meal.symbol)
                        if isCollapsed && !items.isEmpty {
                            Text("(\(items.count))").foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.map(\.nutrients.kcal).reduce(0, +).kcalText) kcal")
                        .monospacedDigit()
                }
                if !items.isEmpty && meal != .drinks {
                    Menu {
                        Button("Enregistrer comme plat", systemImage: "star") {
                            dishName = meal.title
                            dishToSave = meal
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func loadEnergy() async {
        energy = await energyStore.energy(on: day)
    }
}

struct EntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.nutrients.kcal.kcalText) kcal")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = ["\(entry.quantity.gramsText) \(entry.unit.label)"]
        if let brand = entry.brand, !brand.isEmpty { parts.append(brand) }
        if entry.nutrients.alcohol > 0 { parts.append("\(entry.nutrients.alcohol.gramsText) g d'alcool") }
        return parts.joined(separator: " · ")
    }
}
