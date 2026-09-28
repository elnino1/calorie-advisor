import UIKit
import Vision

/// Classification d'image sur l'appareil (framework Vision) pour identifier les aliments d'une photo.
/// Les étiquettes obtenues sont ensuite transmises au modèle Apple Intelligence.
enum PhotoClassifier {
    /// Étiquettes trop génériques pour aider à l'estimation.
    private static let ignored: Set<String> = [
        "food", "dish", "meal", "tableware", "plate", "table", "cutlery", "utensil", "fork", "spoon",
        "knife", "container", "bowl", "structure", "indoor", "outdoor", "wood_processed", "textile",
        "people", "adult", "hand", "consumable", "cookware", "kitchen", "restaurant",
    ]

    static func labels(for image: UIImage, max count: Int = 8) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        do {
            let observations = try await ClassifyImageRequest().perform(on: cgImage, orientation: image.cgOrientation)
            return observations
                .filter { $0.confidence > 0.15 && !ignored.contains($0.identifier) }
                .sorted { $0.confidence > $1.confidence }
                .prefix(count)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        } catch {
            print("Vision classification failed: \(error)")
            return []
        }
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
