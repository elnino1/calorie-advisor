import SwiftData
import SwiftUI
import Vision
import VisionKit

/// Scan d'un code-barre puis recherche dans mes aliments, sinon dans Open Food Facts.
struct BarcodeScanView: View {
    let day: Date
    @Binding var meal: MealType
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @State private var code: String?
    @State private var found: FoodTemplate?
    @State private var notFound = false
    @State private var manual = false
    @State private var error: String?

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if scannerAvailable {
                BarcodeScanner { value in
                    guard code == nil else { return }
                    code = value
                    Task { await lookup(value) }
                }
                .ignoresSafeArea()
            } else {
                ContentUnavailableView("Scanner indisponible", systemImage: "barcode.viewfinder",
                                       description: Text("Autorisez l'accès à la caméra dans Réglages."))
            }

            status
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
        }
        .navigationTitle("Code-barre")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $found) { template in
            PortionView(template: template, day: day, meal: $meal, onDone: onDone)
        }
        .navigationDestination(isPresented: $manual) {
            ManualEntryView(day: day, meal: $meal, barcode: code, onDone: onDone)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error {
            VStack(spacing: 8) {
                Text(error).foregroundStyle(.secondary)
                Button("Réessayer") { reset() }
            }
        } else if notFound, let code {
            VStack(spacing: 8) {
                Text("Produit \(code) introuvable dans Open Food Facts.")
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Saisir manuellement") { manual = true }.buttonStyle(.borderedProminent)
                    Button("Rescanner") { reset() }.buttonStyle(.bordered)
                }
            }
        } else if code != nil {
            HStack { ProgressView(); Text("Recherche du produit…") }
        } else {
            Text("Visez le code-barre du produit").foregroundStyle(.secondary)
        }
    }

    private func reset() {
        code = nil
        notFound = false
        error = nil
    }

    private func lookup(_ barcode: String) async {
        let local = FoodTemplate(name: "", unit: .gram, referenceQuantity: 100, nutrients: .zero,
                                 defaultQuantity: 100, barcode: barcode, source: .saved)
        if let saved = FoodLogger.savedFood(matching: local, in: context) {
            found = saved.template
            return
        }
        do {
            if let product = try await OpenFoodFacts.product(barcode: barcode) {
                found = product
            } else {
                notFound = true
            }
        } catch {
            self.error = "Connexion impossible : \(error.localizedDescription)"
        }
    }
}

/// Enveloppe SwiftUI de `DataScannerViewController` (VisionKit).
private struct BarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !scanner.isScanning { try? scanner.startScanning() }
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onCode(value)
                    return
                }
            }
        }
    }
}
