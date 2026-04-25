import CoreGraphics
import Foundation

struct OCRTextObservation: Identifiable, Hashable {
    let id: UUID
    let text: String
    let rect: CGRect
    let confidence: Float

    init(id: UUID = UUID(), text: String, rect: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.rect = rect
        self.confidence = confidence
    }
}
