// ResultView: Displays redaction results and sharing options

import SwiftUI
import UIKit

private enum RegionSelectionAction: String, CaseIterable, Identifiable {
    case blur = "BLUR"
    case keep = "KEEP"

    var id: String { rawValue }
}

struct ResultView: View {
    let result: DetectionResult
    @State private var selectedTab: Tab = .scrubbed
    @State private var isShowingShareSheet = false
    @State private var redactionMode: RedactionIntensityMode = .balanced
    @State private var regionSelections: [UUID: RegionSelectionAction] = [:]
    @State private var customizedImage: UIImage?
    private let imageRedactor = ImageRedactor()

    private enum Tab: String, CaseIterable, Identifiable {
        case original = "Original"
        case scrubbed = "Scrubbed"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Safe-to-share copy created")
                    Text("Safe-to-Share Output")
                        .font(.title3.bold())

                    Picker("Preview", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Redaction Controls")
                            .font(.headline)

                        HStack(spacing: 8) {
                            modeButton(.balanced)
                            modeButton(.highPrivacy)
                        }

                        HStack(spacing: 8) {
                            Button("BLUR ALL") {
                                setAllSelections(.blur)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("KEEP ALL") {
                                setAllSelections(.keep)
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(selectableRegions) { region in
                            keepBlurButton(for: region)
                        }
                    }
                    .padding(14)
                    .background(cardBackground)

                    HStack(spacing: 10) {
                        Button {
                            isShowingShareSheet = true
                        } label: {
                            Label("Share Scrubbed Image", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            UIImageWriteToSavedPhotosAlbum(customizedImage ?? result.scrubbedImage, nil, nil, nil)
                        } label: {
                            Label("Save Copy", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(14)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Summary")
                            .font(.headline)
                        if result.regions.isEmpty {
                            Text("No sensitive regions found.")
                        } else {
                            ForEach(summaryLines, id: \.self) { line in
                                Text(line)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What This Data Could Leak")
                            .font(.headline)
                        ForEach(leakRiskLines, id: \.self) { item in
                            Label(item, systemImage: "exclamationmark.shield")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(cardBackground)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Time")
                            .font(.headline)
                        Text("Face detection: \(timingString(result.timings.faceDetectionMs))")
                            .foregroundStyle(.secondary)
                        Text("OCR: \(timingString(result.timings.ocrMs))")
                            .foregroundStyle(.secondary)
                        Text("PHI rules: \(timingString(result.timings.phiDetectionMs))")
                            .foregroundStyle(.secondary)
                        Text("Redaction: \(timingString(result.timings.redactionMs))")
                            .foregroundStyle(.secondary)
                        Text("Total: \(timingString(result.timings.totalMs))")
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(cardBackground)
                }
                .padding(20)
            }
            .navigationTitle("Result")
            .background(Color(red: 0.97, green: 0.98, blue: 1.0).ignoresSafeArea())
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [customizedImage ?? result.scrubbedImage])
            }
            .onAppear(perform: configureDefaults)
            .onChange(of: redactionMode) { _ in regenerateImage() }
            .onChange(of: regionSelections) { _ in regenerateImage() }
        }
    }

    private var previewImage: UIImage {
        switch selectedTab {
        case .original:
            return result.originalImage
        case .scrubbed:
            return customizedImage ?? result.scrubbedImage
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safe-to-Share Output")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text("Sensitive details are hidden in the rendered copy below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private var summaryLines: [String] {
        let grouped = Dictionary(grouping: effectiveRegions, by: \.label)
        let sortedLabels = grouped.keys.sorted()
        if sortedLabels.isEmpty {
            return ["No detections found."]
        }
        var lines = sortedLabels.map { label in
            "\(label): \(grouped[label]?.count ?? 0)"
        }
        lines.append("Total regions: \(effectiveRegions.count)")
        return lines
    }

    private var leakRiskLines: [String] {
        let labels = Set(effectiveRegions.map(\.label))
        var lines: [String] = []

        if labels.contains("DATE OF BIRTH") {
            lines.append("Date of birth can be used to verify identity or security questions.")
        }
        if labels.contains("MEDICAL RECORD NUMBER") {
            lines.append("Medical record numbers can link someone to clinical records.")
        }
        if labels.contains("INSURANCE ID") {
            lines.append("Insurance IDs can enable benefits fraud and account misuse.")
        }
        if labels.contains("PHONE NUMBER") || labels.contains("EMAIL ADDRESS") || labels.contains("ADDRESS") {
            lines.append("Contact details can enable phishing, social engineering, and harassment.")
        }
        if labels.contains("SOCIAL SECURITY NUMBER") {
            lines.append("SSNs can directly enable identity theft and financial fraud.")
        }
        if labels.contains("PATIENT ID") || labels.contains("PATIENT") {
            lines.append("Patient identifiers can reveal healthcare association and treatment context.")
        }
        if labels.contains("PRESCRIPTION NUMBER") {
            lines.append("Prescription identifiers can reveal medication profile and refill timelines.")
        }
        if labels.contains("EXPIRATION DATE") {
            lines.append("Expiration dates can help validate linked IDs or cards when combined with other data.")
        }
        if labels.contains("DRIVER LICENSE NUMBER") {
            lines.append("Driver license numbers can enable identity verification abuse and credential fraud.")
        }
        if labels.contains("STAFF BADGE INFO") || labels.contains("BARCODE") || labels.contains("BARCODE / ID VALUE") {
            lines.append("Badge identifiers and barcodes can expose employee identity and internal access references.")
        }
        if labels.contains("BADGE PHOTO") {
            lines.append("Badge photos can reveal identity and workplace affiliation.")
        }
        if labels.contains("FACE") {
            lines.append("Visible faces can reveal identity, location, and clinical presence.")
        }

        if lines.isEmpty {
            lines.append("No high-risk identifiers were detected in this scan.")
        }
        return lines
    }

    private func timingString(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }

    private var selectableRegions: [RedactionRegion] {
        result.regions.sorted {
            if $0.label == $1.label {
                if $0.rect.minY == $1.rect.minY {
                    return $0.rect.minX < $1.rect.minX
                }
                return $0.rect.minY < $1.rect.minY
            }
            return $0.label < $1.label
        }
    }

    private var effectiveRegions: [RedactionRegion] {
        result.regions.compactMap { region in
            let action = regionSelections[region.id] ?? .blur
            guard action == .blur else { return nil }
            return region
        }
    }

    private func configureDefaults() {
        guard regionSelections.isEmpty else { return }
        var defaults: [UUID: RegionSelectionAction] = [:]
        selectableRegions.forEach { defaults[$0.id] = .blur }
        regionSelections = defaults
        regenerateImage()
    }

    private func regenerateImage() {
        customizedImage = imageRedactor.redact(
            image: result.originalImage,
            regions: effectiveRegions,
            intensityMode: redactionMode
        )
    }

    @ViewBuilder
    private func modeButton(_ mode: RedactionIntensityMode) -> some View {
        let isSelected = redactionMode == mode
        Button(mode.rawValue.uppercased()) {
            redactionMode = mode
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func keepBlurButton(for region: RedactionRegion) -> some View {
        let action = regionSelections[region.id] ?? .blur
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(region.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(regionSubtitle(for: region))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action.rawValue) {
                regionSelections[region.id] = action == .blur ? .keep : .blur
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(action == .blur ? Color.red.opacity(0.90) : Color.green.opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }

    private func setAllSelections(_ action: RegionSelectionAction) {
        var updated: [UUID: RegionSelectionAction] = [:]
        selectableRegions.forEach { updated[$0.id] = action }
        regionSelections = updated
    }

    private func regionSubtitle(for region: RedactionRegion) -> String {
        "x:\(Int(region.rect.minX.rounded())) y:\(Int(region.rect.minY.rounded()))"
    }
}
