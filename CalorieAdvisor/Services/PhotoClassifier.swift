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

    /// Classe l'image entière puis chaque quart et le centre : sur une image entière, l'aliment
    /// dominant écrase les autres (une assiette quinoa-bœuf-avocat ne donnait que « quinoa »).
    /// Pour chaque étiquette, on garde la meilleure confiance obtenue.
    static func labels(for image: UIImage, max count: Int = 10) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        let regions = [
            CGRect(x: 0, y: 0, width: w / 2, height: h / 2),
            CGRect(x: w / 2, y: 0, width: w / 2, height: h / 2),
            CGRect(x: 0, y: h / 2, width: w / 2, height: h / 2),
            CGRect(x: w / 2, y: h / 2, width: w / 2, height: h / 2),
            CGRect(x: w / 4, y: h / 4, width: w / 2, height: h / 2),
        ]
        let images = [cgImage] + regions.compactMap { cgImage.cropping(to: $0.integral) }

        var best: [String: Float] = [:]
        for (index, part) in images.enumerated() {
            do {
                let observations = try await ClassifyImageRequest().perform(on: part, orientation: image.cgOrientation)
                // Seuil plus exigeant sur les zones, où les faux positifs sont plus fréquents.
                let threshold: Float = index == 0 ? 0.08 : 0.25
                for observation in observations
                where observation.confidence > threshold && !ignored.contains(observation.identifier) {
                    best[observation.identifier] = Swift.max(best[observation.identifier] ?? 0, observation.confidence)
                }
            } catch {
                print("Vision classification failed: \(error)")
            }
        }
        return best
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key.replacingOccurrences(of: "_", with: " ") }
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
