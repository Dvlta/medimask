import Foundation

final class PHIDetector {
    let phiPatterns: [(label: String, regex: String)] = [
        ("EMAIL", #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#),
        ("PHONE", #"\b(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#),
        ("DOB", #"\b(DOB|Date of Birth|Birth Date)\b[:\s]*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#),
        ("MRN", #"\b(MRN|Medical Record|Medical Record Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("PATIENT ID", #"\b(Patient ID|Patient #|Patient Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("INSURANCE ID", #"\b(Insurance ID|Policy #|Policy Number|Member ID)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("RX", #"\b(Rx|Prescription|Prescription #|Rx #)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
        ("SSN", #"\b\d{3}-\d{2}-\d{4}\b"#),
        ("DATE", #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#)
    ]

    private let keywordMap: [(keyword: String, label: String)] = [
        ("patient", "PATIENT"),
        ("dob", "DOB"),
        ("date of birth", "DOB"),
        ("mrn", "MRN"),
        ("medical record", "MRN"),
        ("insurance", "INSURANCE ID"),
        ("member id", "INSURANCE ID"),
        ("rx", "RX"),
        ("prescription", "RX"),
        ("address", "ADDRESS"),
        ("phone", "PHONE"),
        ("email", "EMAIL"),
        ("ssn", "SSN")
    ]

    func detectPHI(in observations: [OCRTextObservation]) -> [RedactionRegion] {
        observations.compactMap { observation in
            let detectedLabel = matchLabel(in: observation.text)
            guard let detectedLabel else { return nil }

            return RedactionRegion(
                rect: observation.rect.insetBy(dx: -8, dy: -6),
                type: .phiText,
                label: detectedLabel,
                confidence: observation.confidence,
                source: "phi-regex",
                redactionStyle: .blackBox
            )
        }
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
}
