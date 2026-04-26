import CoreGraphics
import Foundation
#if canImport(ZeticMLange)
import ZeticMLange
#endif

struct PHIDetectionReport {
    let regions: [RedactionRegion]
    let backend: String
}

final class SensitiveTextRegionDetector {
    private let melangeDetector = MelangeTextAnonymizerService()
    private let fallbackDetector = PHIDetector()

    func detectPHI(in observations: [OCRTextObservation]) async -> PHIDetectionReport {
        if let melangeReport = try? await melangeDetector.detectPHI(in: observations) {
            if melangeReport.backend == "melange-text-anonymizer" {
                return melangeReport
            }

            if melangeReport.backend.hasPrefix("melange-text-anonymizer"),
               melangeReport.backend != "melange-text-anonymizer-blocked",
               melangeReport.backend != "melange-text-anonymizer-unavailable",
               melangeReport.backend != "melange-text-anonymizer-unconfigured",
               melangeReport.backend != "melange-text-anonymizer-missing-tokenizer",
               melangeReport.backend != "melange-text-anonymizer-missing-labels" {
                return melangeReport
            }

            let fallbackRegions = fallbackDetector.detectPHI(in: observations)
            return PHIDetectionReport(
                regions: fallbackRegions,
                backend: "phi-regex-fallback<\(melangeReport.backend)>"
            )
        }

        let fallbackRegions = fallbackDetector.detectPHI(in: observations)
        return PHIDetectionReport(
            regions: fallbackRegions,
            backend: "phi-regex-error-fallback"
        )
    }
}

final class MelangeTextAnonymizerService {
    private let modelMaxLength = 128
    private let tokenizer: MelangeTextTokenizer?
    private let idToLabel: [Int: String]

    init(bundle: Bundle = .main) {
        tokenizer = try? MelangeTextTokenizer(bundle: bundle)
        idToLabel = Self.loadLabels(bundle: bundle)
    }

    func detectPHI(in observations: [OCRTextObservation]) async throws -> PHIDetectionReport {
        let configuration = MelangeConfiguration.textAnonymizer
        guard configuration.isConfigured else {
            Logger.app.info("Melange text anonymizer skipped because configuration is missing.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-unconfigured")
        }

        guard let tokenizer else {
            Logger.app.error("Melange text anonymizer tokenizer resource is unavailable.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-missing-tokenizer")
        }

        guard !idToLabel.isEmpty else {
            Logger.app.error("Melange text anonymizer label resource is unavailable.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-missing-labels")
        }

        #if canImport(ZeticMLange)
        let model = try ZeticMLangeModel(
            personalKey: configuration.personalKey,
            name: configuration.modelName,
            version: configuration.modelVersionNumber,
            onDownload: { progress in
                Logger.app.info("Melange text anonymizer download progress: \(progress, privacy: .public)")
            }
        )

        let chunks = makeChunks(from: observations, tokenizer: tokenizer)
        var detectedRegions: [RedactionRegion] = []

        for chunk in chunks {
            let encodedTokens = tokenizer.encodeDetailed(chunk.text)
            let preparedInput = prepareInput(from: encodedTokens, tokenizer: tokenizer)
            let outputs = try model.run(inputs: [
                preparedInput.inputIds,
                preparedInput.attentionMask
            ])

            guard let logitsTensor = outputs.first else {
                Logger.app.error("Melange text anonymizer returned no output tensor.")
                continue
            }

            let entities = decodeEntities(
                from: logitsTensor,
                encodedTokens: preparedInput.encodedTokens,
                attentionMask: preparedInput.attentionMaskValues
            )
            detectedRegions.append(contentsOf: regions(from: entities, in: chunk))
        }

        return PHIDetectionReport(
            regions: deduplicatedRegions(detectedRegions),
            backend: "melange-text-anonymizer"
        )
        #else
        Logger.app.info("Melange text anonymizer configured but ZeticMLange is unavailable in this build.")
        return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-unavailable")
        #endif
    }

    private func prepareInput(
        from encodedTokens: [MelangeEncodedToken],
        tokenizer: MelangeTextTokenizer
    ) -> PreparedAnonymizerInput {
        var paddedTokens = encodedTokens
        if paddedTokens.count > modelMaxLength {
            paddedTokens = Array(paddedTokens.prefix(modelMaxLength))
            if let lastToken = paddedTokens.last, lastToken.id != tokenizer.eosId {
                paddedTokens[paddedTokens.count - 1] = MelangeEncodedToken(
                    id: tokenizer.eosId,
                    rawToken: nil,
                    characterRange: nil
                )
            }
        } else if paddedTokens.count < modelMaxLength {
            paddedTokens.append(contentsOf: Array(repeating: MelangeEncodedToken(
                id: tokenizer.padId,
                rawToken: nil,
                characterRange: nil
            ), count: modelMaxLength - paddedTokens.count))
        }

        let inputIds = paddedTokens.map(\.id)
        let attentionMaskValues = paddedTokens.map { token in
            token.id == tokenizer.padId ? 0 : 1
        }

        return PreparedAnonymizerInput(
            encodedTokens: paddedTokens,
            inputIds: createTensor(from: inputIds),
            attentionMask: createTensor(from: attentionMaskValues),
            attentionMaskValues: attentionMaskValues
        )
    }

    private func createTensor(from values: [Int]) -> Tensor {
        let int64Values = values.map(Int64.init)
        let data = int64Values.withUnsafeBufferPointer { Data(buffer: $0) }
        return Tensor(data: data, dataType: BuiltinDataType.int64, shape: [1, modelMaxLength])
    }

    private func decodeEntities(
        from logitsTensor: Tensor,
        encodedTokens: [MelangeEncodedToken],
        attentionMask: [Int]
    ) -> [DetectedEntity] {
        let classCount = idToLabel.count
        guard classCount > 0 else { return [] }

        let floatValues = logitsTensor.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }

        let sequenceLength = min(floatValues.count / classCount, encodedTokens.count)
        var entities: [DetectedEntity] = []
        var activeEntity: ActiveEntity?

        for tokenIndex in 0..<sequenceLength {
            guard tokenIndex < attentionMask.count, attentionMask[tokenIndex] != 0 else {
                continue
            }

            let token = encodedTokens[tokenIndex]
            guard let tokenRange = token.characterRange else {
                continue
            }

            let offset = tokenIndex * classCount
            let scores = floatValues[offset..<(offset + classCount)]
            guard let classification = tokenClassification(from: Array(scores)) else {
                continue
            }

            let label = idToLabel[classification.index] ?? "O"
            if label == "O" {
                if let activeEntity {
                    entities.append(activeEntity.finalize())
                }
                activeEntity = nil
                continue
            }

            let entityLabel = normalizedEntityLabel(for: label)
            if label.hasPrefix("B-") || activeEntity?.label != entityLabel {
                if let activeEntity {
                    entities.append(activeEntity.finalize())
                }
                activeEntity = ActiveEntity(
                    label: entityLabel,
                    range: tokenRange,
                    accumulatedProbability: classification.probability,
                    accumulatedMargin: classification.margin,
                    tokenCount: 1
                )
            } else if var current = activeEntity {
                current.range = min(current.range.lowerBound, tokenRange.lowerBound)..<max(current.range.upperBound, tokenRange.upperBound)
                current.accumulatedProbability += classification.probability
                current.accumulatedMargin += classification.margin
                current.tokenCount += 1
                activeEntity = current
            }
        }

        if let activeEntity {
            entities.append(activeEntity.finalize())
        }

        return entities
    }

    private func regions(from entities: [DetectedEntity], in chunk: OCRChunk) -> [RedactionRegion] {
        entities.compactMap { entity in
            let matchingObservations = chunk.observations.filter { observation in
                rangesOverlap(lhs: observation.characterRange, rhs: entity.range)
            }

            guard !matchingObservations.isEmpty else {
                return nil
            }

            let mergedRect = matchingObservations
                .map(\.observation.rect)
                .reduce(CGRect.null) { partial, rect in
                    partial.isNull ? rect : partial.union(rect)
                }

            let boundedRect = mergedRect.insetBy(dx: -8, dy: -6)
            let averageOCRConfidence = matchingObservations.map(\.observation.confidence).reduce(0, +) / Float(matchingObservations.count)
            let entityText = text(in: entity.range, from: chunk.text)
            let matchedText = matchingObservations.map(\.observation.text).joined(separator: " ")
            let label = refinedDisplayLabel(
                for: entity,
                text: entityText.isEmpty ? matchedText : entityText + " " + matchedText
            )

            return RedactionRegion(
                rect: boundedRect,
                type: .phiText,
                label: label,
                confidence: max(entity.confidence, averageOCRConfidence),
                source: "melange-text-anonymizer",
                redactionStyle: .blur
            )
        }
    }

    private func makeChunks(
        from observations: [OCRTextObservation],
        tokenizer: MelangeTextTokenizer
    ) -> [OCRChunk] {
        let lines = groupedLines(from: observations)
        var chunks: [OCRChunk] = []
        var currentText = ""
        var currentObservations: [ChunkObservation] = []

        func appendCurrentChunk() {
            let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty, !currentObservations.isEmpty else { return }
            chunks.append(OCRChunk(text: trimmedText, observations: currentObservations))
            currentText = ""
            currentObservations = []
        }

        for line in lines {
            let lineText = line.map(\.text).joined(separator: " ")
            guard !lineText.isEmpty else { continue }

            let candidateText = currentText.isEmpty ? lineText : currentText + "\n" + lineText
            if tokenizer.encodeDetailed(candidateText).count > modelMaxLength, !currentText.isEmpty {
                appendCurrentChunk()
            }

            let lineStart = currentText.isEmpty ? 0 : currentText.count + 1
            if !currentText.isEmpty {
                currentText += "\n"
            }
            currentText += lineText

            var cursor = lineStart
            for (index, observation) in line.enumerated() {
                let start = cursor
                let end = start + observation.text.count
                currentObservations.append(
                    ChunkObservation(
                        observation: observation,
                        characterRange: start..<end
                    )
                )
                cursor = end
                if index < line.count - 1 {
                    cursor += 1
                }
            }
        }

        appendCurrentChunk()
        return chunks
    }

    private func groupedLines(from observations: [OCRTextObservation]) -> [[OCRTextObservation]] {
        let sorted = observations
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if abs($0.rect.minY - $1.rect.minY) < 14 {
                    return $0.rect.minX < $1.rect.minX
                }
                return $0.rect.minY < $1.rect.minY
            }

        var lines: [[OCRTextObservation]] = []
        for observation in sorted {
            if var lastLine = lines.last,
               let reference = lastLine.first,
               abs(reference.rect.midY - observation.rect.midY) <= max(reference.rect.height, observation.rect.height) * 0.7 {
                lastLine.append(observation)
                lastLine.sort { $0.rect.minX < $1.rect.minX }
                lines[lines.count - 1] = lastLine
            } else {
                lines.append([observation])
            }
        }

        return lines
    }

    private func deduplicatedRegions(_ regions: [RedactionRegion]) -> [RedactionRegion] {
        var deduplicated: [RedactionRegion] = []

        for region in regions.sorted(by: regionSortPrecedence) {
            let overlapsExisting = deduplicated.contains { existing in
                overlapRatio(lhs: existing.rect, rhs: region.rect) > 0.5
            }

            if !overlapsExisting {
                deduplicated.append(region)
            }
        }

        return deduplicated
    }

    private func regionSortPrecedence(_ lhs: RedactionRegion, _ rhs: RedactionRegion) -> Bool {
        let lhsPriority = labelPriority(lhs.label)
        let rhsPriority = labelPriority(rhs.label)
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }

        let lhsArea = lhs.rect.width * lhs.rect.height
        let rhsArea = rhs.rect.width * rhs.rect.height
        if lhsArea != rhsArea {
            return lhsArea > rhsArea
        }

        return lhs.confidence > rhs.confidence
    }

    private func labelPriority(_ label: String) -> Int {
        switch label {
        case "SENSITIVE TEXT":
            return 0
        case "LOCATION":
            return 1
        default:
            return 2
        }
    }

    private func normalizedEntityLabel(for label: String) -> String {
        if label.hasPrefix("B-") || label.hasPrefix("I-") {
            return String(label.dropFirst(2))
        }
        return label
    }

    private func displayLabel(for entityLabel: String) -> String {
        switch entityLabel {
        case "PERSON":
            return "PERSON NAME"
        case "LOCATION":
            return "LOCATION"
        case "ADDRESS":
            return "ADDRESS"
        case "EMAIL":
            return "EMAIL ADDRESS"
        case "PHONE_NUMBER":
            return "PHONE NUMBER"
        case "DATE":
            return "DATE"
        case "CREDIT_CARD_NUMBER":
            return "CREDIT CARD NUMBER"
        case "SSN":
            return "SOCIAL SECURITY NUMBER"
        default:
            return entityLabel.replacingOccurrences(of: "_", with: " ").uppercased()
        }
    }

    private func refinedDisplayLabel(for entity: DetectedEntity, text: String) -> String {
        if matches(text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#) {
            return "EMAIL ADDRESS"
        }

        if matches(text, pattern: #"\b(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#) {
            return "PHONE NUMBER"
        }

        if matches(text, pattern: #"\b(DOB|Date of Birth|Birth Date)\b[:\s]*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#) {
            return "DATE OF BIRTH"
        }

        if matches(text, pattern: #"\b(MRN|Medical Record|Medical Record Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#) {
            return "MEDICAL RECORD NUMBER"
        }

        if matches(text, pattern: #"\b(Patient ID|Patient #|Patient Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#) {
            return "PATIENT ID"
        }

        if matches(text, pattern: #"\b(Insurance ID|Policy #|Policy Number|Member ID)\b[:\s#-]*[A-Z0-9-]{4,}\b"#) {
            return "INSURANCE ID"
        }

        if matches(text, pattern: #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#) {
            return "DATE"
        }

        if looksLikeAddress(text) {
            return "ADDRESS"
        }

        if entity.isUncertain {
            return "SENSITIVE TEXT"
        }

        if entity.label == "LOCATION", !looksLikeLocation(text) {
            return "SENSITIVE TEXT"
        }

        return displayLabel(for: entity.label)
    }

    private func tokenClassification(from scores: [Float32]) -> TokenClassification? {
        guard let best = scores.enumerated().max(by: { $0.element < $1.element }) else {
            return nil
        }

        let maxScore = best.element
        let expScores = scores.map { Foundation.exp(Double($0 - maxScore)) }
        let total = expScores.reduce(0, +)
        guard total > 0 else {
            return TokenClassification(index: best.offset, probability: 0, margin: 0)
        }

        let probabilities = expScores.map { Float32($0 / total) }
        let bestProbability = probabilities[best.offset]
        let secondBestProbability = probabilities
            .enumerated()
            .filter { $0.offset != best.offset }
            .map(\.element)
            .max() ?? 0

        return TokenClassification(
            index: best.offset,
            probability: bestProbability,
            margin: bestProbability - secondBestProbability
        )
    }

    private func text(in range: Range<Int>, from text: String) -> String {
        guard range.lowerBound >= 0,
              range.upperBound <= text.count,
              range.lowerBound < range.upperBound,
              let start = text.index(text.startIndex, offsetBy: range.lowerBound, limitedBy: text.endIndex),
              let end = text.index(text.startIndex, offsetBy: range.upperBound, limitedBy: text.endIndex),
              start <= end else {
            return ""
        }

        return String(text[start..<end])
    }

    private func matches(_ text: String, pattern: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
            .flatMap { regex in
                regex.firstMatch(in: text, options: [], range: range)
            } != nil
    }

    private func looksLikeAddress(_ text: String) -> Bool {
        matches(
            text,
            pattern: #"\b\d{1,6}\s+[A-Z0-9.'-]+(?:\s+[A-Z0-9.'-]+){0,4}\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct|Way|Circle|Cir|Place|Pl|Suite|Ste|Unit|Apt)\b"#
        )
    }

    private func looksLikeLocation(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let locationCues = [
            "street", " st", "avenue", " ave", "road", " rd", "boulevard", "blvd",
            "drive", " dr", "lane", " ln", "suite", "unit", "apt", "city", "state",
            "zip", "hospital", "clinic", "center", "medical", "department", "room"
        ]

        return looksLikeAddress(text) || locationCues.contains { lowercased.contains($0) }
    }

    private func rangesOverlap(lhs: Range<Int>, rhs: Range<Int>) -> Bool {
        lhs.overlaps(rhs)
    }

    private func overlapRatio(lhs: CGRect, rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let minArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard minArea > 0 else { return 0 }
        return intersectionArea / minArea
    }

    private static func loadLabels(
        resourceName: String = "ResourcesTextAnonymizer_labels",
        bundle: Bundle = .main
    ) -> [Int: String] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }

        var labels: [Int: String] = [:]
        for (key, value) in json {
            if let integerKey = Int(key) {
                labels[integerKey] = value
            }
        }
        return labels
    }
}

private struct PreparedAnonymizerInput {
    let encodedTokens: [MelangeEncodedToken]
    let inputIds: Tensor
    let attentionMask: Tensor
    let attentionMaskValues: [Int]
}

private struct OCRChunk {
    let text: String
    let observations: [ChunkObservation]
}

private struct ChunkObservation {
    let observation: OCRTextObservation
    let characterRange: Range<Int>
}

private struct TokenClassification {
    let index: Int
    let probability: Float32
    let margin: Float32
}

private struct ActiveEntity {
    let label: String
    var range: Range<Int>
    var accumulatedProbability: Float32
    var accumulatedMargin: Float32
    var tokenCount: Int

    func finalize() -> DetectedEntity {
        let divisor = Float32(max(tokenCount, 1))
        let averageProbability = accumulatedProbability / divisor
        let averageMargin = accumulatedMargin / divisor
        let confidence = Float(max(0.45, min(0.99, averageProbability)))
        let isUncertain = averageProbability < 0.60 || averageMargin < 0.15
        return DetectedEntity(
            label: label,
            range: range,
            confidence: confidence,
            isUncertain: isUncertain
        )
    }
}

private struct DetectedEntity {
    let label: String
    let range: Range<Int>
    let confidence: Float
    let isUncertain: Bool
}
