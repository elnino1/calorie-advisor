import PhotosUI
import SwiftUI

/// Photo d'un plat → étiquettes Vision → estimation Apple Intelligence → vérification.
struct PhotoEntryView: View {
    let day: Date
    @Binding var meal: MealType
    let onDone: () -> Void

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var labels: [String] = []
    @State private var classifying = false
    @State private var details = ""
    @State private var estimating = false
    @State private var estimate: EstimateBox?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity)
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Prendre une photo", systemImage: "camera") { showCamera = true }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choisir dans la photothèque", systemImage: "photo.on.rectangle")
                }
            }

            if image != nil {
                Section {
                    if classifying {
                        HStack { ProgressView(); Text("Analyse de l'image…") }
                    } else if labels.isEmpty {
                        Text("Aucun aliment reconnu : décrivez le plat ci-dessous.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(labels.joined(separator: ", "))
                    }
                } header: {
                    Text("Éléments détectés")
                }

                Section {
                    TextField("Ex. : assiette de pâtes bolognaise, grande portion, un verre de rouge",
                              text: $details, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Précisions (recommandé)")
                } footer: {
                    Text("La reconnaissance d'image peut manquer des aliments : listez ce qu'il y a dans l'assiette (ex. « quinoa, filet de bœuf, avocat »). Le modèle d'Apple Intelligence s'exécute sur l'iPhone.")
                }

                Section {
                    Button {
                        Task { await runEstimate() }
                    } label: {
                        HStack {
                            if estimating { ProgressView() }
                            Label("Estimer les calories", systemImage: "sparkles")
                        }
                    }
                    .disabled(estimating || classifying || (labels.isEmpty && details.isEmpty)
                              || !FoodIntelligence.isAvailable)
                    if !FoodIntelligence.isAvailable {
                        Text(FoodIntelligence.statusText).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Photo du plat")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $image).ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    image = UIImage(data: data)
                }
            }
        }
        .task(id: image) { await classify() }
        .navigationDestination(item: $estimate) { box in
            EstimateReviewView(items: box.items, day: day, meal: $meal, onDone: onDone)
        }
    }

    private func classify() async {
        guard let image else { return }
        classifying = true
        labels = await PhotoClassifier.labels(for: image)
        classifying = false
    }

    private func runEstimate() async {
        estimating = true
        error = nil
        defer { estimating = false }
        do {
            let items = try await FoodIntelligence.estimateMeal(description: details, photoLabels: labels)
            if items.isEmpty { error = "Aucun aliment identifié, précisez la description." }
            else { estimate = EstimateBox(items: items) }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Permet d'utiliser `navigationDestination(item:)` avec une liste.
struct EstimateBox: Hashable {
    var items: [FoodTemplate]
}

/// Appareil photo (UIKit).
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
