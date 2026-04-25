import Foundation

struct ProcessingTimings: Codable, Hashable {
    let faceDetectionMs: Double
    let ocrMs: Double
    let phiDetectionMs: Double
    let redactionMs: Double
    let totalMs: Double

    static let zero = ProcessingTimings(
        faceDetectionMs: 0,
        ocrMs: 0,
        phiDetectionMs: 0,
        redactionMs: 0,
        totalMs: 0
    )
}
