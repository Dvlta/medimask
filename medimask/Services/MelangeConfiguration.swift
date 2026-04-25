import Foundation

struct MelangeConfiguration {
    let personalKey: String
    let modelName: String
    let modelVersion: String?

    var isConfigured: Bool {
        !personalKey.isEmpty && !modelName.isEmpty
    }

    static var faceDetection: MelangeConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        let personalKey = stringValue(for: "MelangePersonalKey", in: info) ?? ""
        let modelName = stringValue(for: "MelangeFaceModelName", in: info)
            ?? "google/MediaPipe-Face-Detection"
        let modelVersion = stringValue(for: "MelangeFaceModelVersion", in: info)

        return MelangeConfiguration(
            personalKey: personalKey,
            modelName: modelName,
            modelVersion: modelVersion
        )
    }

    private static func stringValue(for key: String, in info: [String: Any]) -> String? {
        guard let value = info[key] as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
