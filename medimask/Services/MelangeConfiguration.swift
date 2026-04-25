import Foundation

struct MelangeConfiguration {
    let personalKey: String
    let modelName: String
    let modelVersion: String?

    var isConfigured: Bool {
        !personalKey.isEmpty && !modelName.isEmpty
    }

    var modelVersionNumber: Int {
        if let modelVersion, let parsed = Int(modelVersion) {
            return parsed
        }

        return 1
    }

    static var faceDetection: MelangeConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        let bundlePersonalKey = stringValue(for: "MelangePersonalKey", in: info) ?? ""
        let localPersonalKey = MelangeLocalSecrets.personalKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let personalKey = bundlePersonalKey.isEmpty ? localPersonalKey : bundlePersonalKey
        let modelName = stringValue(for: "MelangeFaceModelName", in: info)
            ?? "google/MediaPipe-Face-Detection"
        let modelVersion = stringValue(for: "MelangeFaceModelVersion", in: info)

        let keyPreview: String
        if personalKey.isEmpty {
            keyPreview = "missing"
        } else {
            keyPreview = String(personalKey.prefix(6)) + "..."
        }

        Logger.app.info(
            "Melange config resolved - bundle key present: \(!bundlePersonalKey.isEmpty, privacy: .public), local key present: \(!localPersonalKey.isEmpty, privacy: .public), active key: \(keyPreview, privacy: .public), model: \(modelName, privacy: .public), version: \(modelVersion ?? "<empty>", privacy: .public)"
        )

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
