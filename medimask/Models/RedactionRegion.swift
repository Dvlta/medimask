import CoreGraphics
import Foundation

enum RegionType: String, Codable, CaseIterable {
    case face
    case phiText
    case object
    case unknown
}

enum RedactionStyle: String, Codable, CaseIterable {
    case blackBox
    case blur
    case pixelate
}

struct RedactionRegion: Identifiable, Codable, Hashable {
    let id: UUID
    let rect: CGRect
    let type: RegionType
    let label: String
    let confidence: Float
    let source: String
    let redactionStyle: RedactionStyle

    init(
        id: UUID = UUID(),
        rect: CGRect,
        type: RegionType,
        label: String,
        confidence: Float,
        source: String,
        redactionStyle: RedactionStyle
    ) {
        self.id = id
        self.rect = rect
        self.type = type
        self.label = label
        self.confidence = confidence
        self.source = source
        self.redactionStyle = redactionStyle
    }
}
