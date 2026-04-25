import Foundation
import CoreGraphics

final class PHIDetector {
    private let phiPatterns: [(label: String, regex: String)] = [
        ("EMAIL ADDRESS", #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#),
        ("PHONE NUMBER", #"\b(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#),
        ("DATE OF BIRTH", #"\b(DOB|Date of Birth|Birth Date)\b[:\s]*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#),
        ("MEDICAL RECORD NUMBER", #"\b(MRN|Medical Record|Medical Record Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("PATIENT ID", #"\b(Patient ID|Patient #|Patient Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("INSURANCE ID", #"\b(Insurance ID|Policy #|Policy Number|Member ID)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("PRESCRIPTION NUMBER", #"\b(Rx|Prescription|Prescription #|Rx #)\b[:\s#-]*[A-Z0-9-]{3,}\b"#),
        ("SOCIAL SECURITY NUMBER", #"\b\d{3}-\d{2}-\d{4}\b"#),
        ("DRIVER LICENSE NUMBER", #"\b(DL|DLN|Driver'?s?\s*License|License\s*(No|#|Number))\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("EXPIRATION DATE", #"\b(Exp|Expires|Expiry|Expiration Date|Exp Date)\b[:\s]*\d{1,2}[/-]\d{2,4}\b"#),
        ("EXPIRATION DATE", #"\b\d{2}[/-]\d{2,4}\s*(EXP|EXPIRES|EXPIRY)\b"#),
        ("DATE", #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#)
    ]

    private let keywordMap: [(keyword: String, label: String)] = [
        ("patient", "PATIENT"),
        ("dob", "DATE OF BIRTH"),
        ("date of birth", "DATE OF BIRTH"),
        ("mrn", "MEDICAL RECORD NUMBER"),
        ("medical record", "MEDICAL RECORD NUMBER"),
        ("insurance", "INSURANCE ID"),
        ("member id", "INSURANCE ID"),
        ("rx", "PRESCRIPTION NUMBER"),
        ("prescription", "PRESCRIPTION NUMBER"),
        ("address", "ADDRESS"),
        ("phone", "PHONE NUMBER"),
        ("email", "EMAIL ADDRESS"),
        ("ssn", "SOCIAL SECURITY NUMBER"),
        ("driver license", "DRIVER LICENSE NUMBER"),
        ("driver's license", "DRIVER LICENSE NUMBER"),
        ("license number", "DRIVER LICENSE NUMBER"),
        ("dln", "DRIVER LICENSE NUMBER"),
        ("expiry", "EXPIRATION DATE"),
        ("exp date", "EXPIRATION DATE"),
        ("expiration date", "EXPIRATION DATE")
    ]

    func detectPHI(in observations: [OCRTextObservation]) -> [RedactionRegion] {
        var regions: [RedactionRegion] = observations.compactMap { observation -> RedactionRegion? in
            guard observation.confidence >= 0.18 else { return nil }

            let normalizedText = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedText.isEmpty else { return nil }

            let detectedLabel = matchLabel(in: normalizedText)
            guard let detectedLabel else { return nil }

            let padding = paddingForLabel(detectedLabel)
            return RedactionRegion(
                rect: observation.rect.insetBy(dx: -padding.horizontal, dy: -padding.vertical),
                type: .phiText,
                label: detectedLabel,
                confidence: observation.confidence,
                source: "phi-regex",
                redactionStyle: .blur
            )
        }

        regions.append(contentsOf: badgeProtectionRegions(from: observations))
        return regions
    }

    private func matchLabel(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        for pattern in phiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive]),
               regex.firstMatch(in: text, options: [], range: range) != nil {
                return pattern.label
            }
        }

        let lowercased = text.lowercased()
        return keywordMap.first(where: { lowercased.contains($0.keyword) })?.label
    }

    private func paddingForLabel(_ label: String) -> (horizontal: CGFloat, vertical: CGFloat) {
        if label == "PHONE NUMBER" || label == "EMAIL ADDRESS" || label == "EXPIRATION DATE" {
            return (10, 8)
        }
        if label == "DATE" || label == "DATE OF BIRTH" {
            return (8, 7)
        }
        return (7, 6)
    }

    private func badgeProtectionRegions(from observations: [OCRTextObservation]) -> [RedactionRegion] {
        let badgeKeywords = [
            "badge", "employee", "staff", "registered nurse", "rn", "department",
            "unit", "license", "lic#", "id", "employee id", "barcode", "name:"
        ]

        let badgeLines = observations.filter { observation in
            let lower = observation.text.lowercased()
            return badgeKeywords.contains(where: { lower.contains($0) })
        }

        guard !badgeLines.isEmpty else { return [] }

        let mergedRect = badgeLines
            .map(\.rect)
            .reduce(.null) { partial, rect in
                partial.isNull ? rect : partial.union(rect)
            }

        guard !mergedRect.isNull else { return [] }

        let paddedBadgeRect = mergedRect.insetBy(dx: -26, dy: -24)
        var output: [RedactionRegion] = [
            RedactionRegion(
                rect: paddedBadgeRect,
                type: .phiText,
                label: "STAFF BADGE INFO",
                confidence: 0.95,
                source: "phi-badge",
                redactionStyle: .blur
            )
        ]

        // Blur the likely badge headshot area so ID photos are not publicly visible.
        let badgePhotoRect = CGRect(
            x: paddedBadgeRect.minX + 6,
            y: paddedBadgeRect.minY + 6,
            width: max(42, paddedBadgeRect.width * 0.34),
            height: max(42, paddedBadgeRect.height * 0.54)
        )
        output.append(
            RedactionRegion(
                rect: badgePhotoRect,
                type: .phiText,
                label: "BADGE PHOTO",
                confidence: 0.9,
                source: "phi-badge",
                redactionStyle: .blur
            )
        )

        let barcodeCandidateRegex = #"\b([A-Z0-9]{8,}|\d{8,})\b"#
        let barcodeLines = observations.filter { obs in
            let range = NSRange(obs.text.startIndex..<obs.text.endIndex, in: obs.text)
            let matchedToken = (try? NSRegularExpression(pattern: barcodeCandidateRegex, options: [.caseInsensitive]))?
                .firstMatch(in: obs.text, options: [], range: range) != nil
            let hasBarcodeWord = obs.text.lowercased().contains("barcode")
            return matchedToken || hasBarcodeWord
        }

        if !barcodeLines.isEmpty {
            let barcodeRect = barcodeLines
                .map(\.rect)
                .reduce(.null) { partial, rect in
                    partial.isNull ? rect : partial.union(rect)
                }
                .insetBy(dx: -14, dy: -10)
            output.append(
                RedactionRegion(
                    rect: barcodeRect,
                    type: .phiText,
                    label: "BARCODE / ID VALUE",
                    confidence: 0.88,
                    source: "phi-badge",
                    redactionStyle: .blur
                )
            )
        } else {
            // Fallback for unreadable barcodes: redact lower badge strip where barcode usually appears.
            let fallbackBarcodeRect = CGRect(
                x: paddedBadgeRect.minX + 4,
                y: paddedBadgeRect.maxY - max(30, paddedBadgeRect.height * 0.26),
                width: paddedBadgeRect.width - 8,
                height: max(28, paddedBadgeRect.height * 0.24)
            )
            output.append(
                RedactionRegion(
                    rect: fallbackBarcodeRect,
                    type: .phiText,
                    label: "BARCODE",
                    confidence: 0.8,
                    source: "phi-badge",
                    redactionStyle: .blur
                )
            )
        }

        return output
    }
}
