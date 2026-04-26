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
        let resolved = resolvedPersonalKey()
        let modelName = stringValue(for: "MelangeFaceModelName", in: Bundle.main.infoDictionary ?? [:])
            ?? "google/MediaPipe-Face-Detection"
        let modelVersion = stringValue(for: "MelangeFaceModelVersion", in: Bundle.main.infoDictionary ?? [:])

        let keyPreview: String
        if resolved.personalKey.isEmpty {
            keyPreview = "missing"
        } else {
            keyPreview = String(resolved.personalKey.prefix(6)) + "..."
        }

        Logger.app.info(
            "Melange config resolved - bundle key present: \(!resolved.bundlePersonalKey.isEmpty, privacy: .public), local key present: \(!resolved.localPersonalKey.isEmpty, privacy: .public), active key: \(keyPreview, privacy: .public), model: \(modelName, privacy: .public), version: \(modelVersion ?? "<empty>", privacy: .public)"
        )

        return MelangeConfiguration(
            personalKey: resolved.personalKey,
            modelName: modelName,
            modelVersion: modelVersion
        )
    }

    static var faceLandmark: MelangeConfiguration {
        let resolved = resolvedPersonalKey()
        let info = Bundle.main.infoDictionary ?? [:]
        let modelName = stringValue(for: "MelangeFaceLandmarkModelName", in: info)
            ?? "google/MediaPipe-Face-Landmark"
        let modelVersion = stringValue(for: "MelangeFaceLandmarkModelVersion", in: info)

        Logger.app.info(
            "Melange face landmark config resolved - bundle key present: \(!resolved.bundlePersonalKey.isEmpty, privacy: .public), local key present: \(!resolved.localPersonalKey.isEmpty, privacy: .public), model: \(modelName, privacy: .public), version: \(modelVersion ?? "<empty>", privacy: .public)"
        )

        return MelangeConfiguration(
            personalKey: resolved.personalKey,
            modelName: modelName,
            modelVersion: modelVersion
        )
    }

    static var textAnonymizer: MelangeConfiguration {
        let resolved = resolvedPersonalKey()
        let info = Bundle.main.infoDictionary ?? [:]
        let modelName = stringValue(for: "MelangeTextAnonymizerModelName", in: info)
            ?? "Steve/text-anonymizer-v1"
        let modelVersion = stringValue(for: "MelangeTextAnonymizerModelVersion", in: info)

        Logger.app.info(
            "Melange text anonymizer config resolved - bundle key present: \(!resolved.bundlePersonalKey.isEmpty, privacy: .public), local key present: \(!resolved.localPersonalKey.isEmpty, privacy: .public), model: \(modelName, privacy: .public), version: \(modelVersion ?? "<empty>", privacy: .public)"
        )

        return MelangeConfiguration(
            personalKey: resolved.personalKey,
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

    private static func resolvedPersonalKey() -> (bundlePersonalKey: String, localPersonalKey: String, personalKey: String) {
        let info = Bundle.main.infoDictionary ?? [:]
        let bundlePersonalKey = stringValue(for: "MelangePersonalKey", in: info) ?? ""
        let localPersonalKey = MelangeLocalSecrets.personalKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let personalKey = bundlePersonalKey.isEmpty ? localPersonalKey : bundlePersonalKey
        return (bundlePersonalKey, localPersonalKey, personalKey)
    }
}
