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
    @State private var outputStyle: OutputStyle = .clean
    @State private var selectedLeakCategory: String? = nil
    @State private var selectedLeakRegionID: UUID? = nil
    private let imageRedactor = ImageRedactor()

    private enum Tab: String, CaseIterable, Identifiable {
        case original = "Original"
        case scrubbed = "Scrubbed"

        var id: String { rawValue }
    }

    private enum OutputStyle: String, CaseIterable, Identifiable {
        case clean = "Clean Scrub"
        case insight = "Leak Overlay"

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

                    if selectedTab == .scrubbed {
                        HStack(spacing: 8) {
                            ForEach(OutputStyle.allCases) { style in
                                Button(style.rawValue) {
                                    outputStyle = style
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(outputStyle == style ? Color.accentColor : Color.gray.opacity(0.15))
                                .foregroundStyle(outputStyle == style ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    GeometryReader { geometry in
                        let focusRect = leakFocusRect()
                        let zoom = leakZoomTransform(for: focusRect, containerSize: geometry.size)

                        ZStack(alignment: .topLeading) {
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                if selectedTab == .scrubbed, outputStyle == .insight {
                                    LeakInsightOverlayView(
                                        imageSize: result.originalImage.size,
                                        containerSize: geometry.size,
                                        regions: effectiveRegions,
                                        selectedCategory: selectedLeakCategory,
                                        selectedRegionID: selectedLeakRegionID
                                    )
                                }
                            }
                            .scaleEffect(zoom.scale, anchor: .center)
                            .offset(x: zoom.offset.width, y: zoom.offset.height)
                            .animation(.spring(response: 0.30, dampingFraction: 0.86), value: selectedLeakCategory)
                            .animation(.spring(response: 0.30, dampingFraction: 0.86), value: selectedLeakRegionID)

                            if selectedTab == .scrubbed,
                               outputStyle == .insight,
                               (selectedLeakCategory != nil || selectedLeakRegionID != nil) {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button {
                                            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                                selectedLeakCategory = nil
                                                selectedLeakRegionID = nil
                                            }
                                        } label: {
                                            Label("Reset Zoom", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                            }
                        }
                    }
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if selectedTab == .scrubbed, outputStyle == .insight {
                        leakFilterPanel
                    }

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

                        ForEach(Array(selectableRegions.enumerated()), id: \.element.id) { index, region in
                            keepBlurButton(for: region, index: index + 1)
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
        let filteredRegions = filteredLeakRegions.filter { hasLeakInsight(for: $0.label) }
        let labels = Set(filteredRegions.map(\.label))
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

    private var leakFilterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leak Topics")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    leakChip("ALL", isSelected: selectedLeakCategory == nil) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                            selectedLeakCategory = nil
                            selectedLeakRegionID = nil
                        }
                    }
                    ForEach(leakCategories, id: \.self) { category in
                        leakChip(category, isSelected: selectedLeakCategory == category) {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                                selectedLeakCategory = category
                                selectedLeakRegionID = nil
                            }
                        }
                    }
                }
            }

            if let selectedLeakCategory,
               let bucket = leakGroupedRegions[selectedLeakCategory],
               !bucket.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(bucket.enumerated()), id: \.element.id) { index, region in
                            leakChip(
                                "\(index + 1). \(region.label)",
                                isSelected: selectedLeakRegionID == region.id
                            ) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                                    selectedLeakRegionID = (selectedLeakRegionID == region.id) ? nil : region.id
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    @ViewBuilder
    private func leakChip(_ title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.red : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var leakCategories: [String] {
        Array(leakGroupedRegions.keys).sorted()
    }

    private var leakGroupedRegions: [String: [RedactionRegion]] {
        Dictionary(grouping: effectiveRegions.filter { hasLeakInsight(for: $0.label) }) { leakCategory(for: $0.label) }
    }

    private var filteredLeakRegions: [RedactionRegion] {
        var working = effectiveRegions
        if let selectedLeakCategory {
            working = working.filter { leakCategory(for: $0.label) == selectedLeakCategory }
        }
        if let selectedLeakRegionID {
            working = working.filter { $0.id == selectedLeakRegionID }
        }
        return working
    }

    private func leakCategory(for label: String) -> String {
        let upper = label.uppercased()
        if upper.contains("FACE") { return "FACE" }
        if upper.contains("BADGE") || upper.contains("BARCODE") { return "BADGE" }
        if upper.contains("DOB") || upper.contains("DATE OF BIRTH") { return "DOB" }
        if upper.contains("EXPIRATION") { return "EXPIRATION" }
        if upper.contains("MRN") || upper.contains("PATIENT ID") { return "PATIENT ID" }
        if upper.contains("PHONE") || upper.contains("EMAIL") { return "CONTACT" }
        if upper.contains("DRIVER LICENSE") { return "DRIVER LICENSE" }
        if upper.contains("SSN") { return "SSN" }
        return "OTHER"
    }

    private func leakFocusRect() -> CGRect? {
        let selected: [RedactionRegion]
        if let selectedLeakRegionID {
            selected = effectiveRegions.filter { $0.id == selectedLeakRegionID }
        } else if let selectedLeakCategory {
            selected = effectiveRegions.filter { leakCategory(for: $0.label) == selectedLeakCategory }
        } else {
            selected = []
        }

        guard !selected.isEmpty else { return nil }
        return selected.map(\.rect).reduce(CGRect.null) { partial, rect in
            partial.isNull ? rect : partial.union(rect)
        }
    }

    private func leakZoomTransform(for focusRect: CGRect?, containerSize: CGSize) -> (scale: CGFloat, offset: CGSize) {
        guard let focusRect,
              !focusRect.isNull,
              focusRect.width > 0,
              focusRect.height > 0 else {
            return (1.0, .zero)
        }

        let mapped = CoordinateMapper.mapImageRect(
            focusRect,
            imageSize: result.originalImage.size,
            containerSize: containerSize,
            padding: 8
        )
        guard mapped != .zero else {
            return (1.0, .zero)
        }

        let desiredCoverage: CGFloat = 0.60
        let scaleX = containerSize.width / max(mapped.width / desiredCoverage, 1)
        let scaleY = containerSize.height / max(mapped.height / desiredCoverage, 1)
        let scale = min(2.7, max(1.0, min(scaleX, scaleY)))

        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let target = CGPoint(x: mapped.midX, y: mapped.midY)
        let dx = (center.x - target.x) * scale
        let dy = (center.y - target.y) * scale
        return (scale, CGSize(width: dx, height: dy))
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
    private func keepBlurButton(for region: RedactionRegion, index: Int) -> some View {
        let action = regionSelections[region.id] ?? .blur
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(index). \(region.label)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(regionDetailText(for: region))
                    .font(.caption2)
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
        let detector = region.source
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        return "\(region.displayCategory) - \(detector)"
    }

    private func regionDetailText(for region: RedactionRegion) -> String {
        let source = region.source.replacingOccurrences(of: "-", with: " ")
        let confidence = Int((region.confidence * 100).rounded())
        return "\(descriptionForLabel(region.label)) Source: \(source). Confidence: \(confidence)%."
    }

    private func descriptionForLabel(_ label: String) -> String {
        let upper = label.uppercased()
        if upper.contains("LOCATION ADDRESS") || upper == "ADDRESS" {
            return "Address-like text found in the image."
        }
        if upper.contains("FACE") {
            return "Detected visible human face region."
        }
        if upper.contains("BADGE PHOTO") {
            return "Photo area likely inside an ID/badge."
        }
        if upper.contains("BADGE") || upper.contains("BARCODE") {
            return "Badge/employee identifier content found."
        }
        if upper.contains("DATE OF BIRTH") {
            return "Birth date indicator text detected."
        }
        if upper.contains("EXPIRATION") {
            return "Expiration-related date detected."
        }
        if upper.contains("PHONE") {
            return "Phone number pattern detected."
        }
        if upper.contains("EMAIL") {
            return "Email address pattern detected."
        }
        if upper.contains("DRIVER LICENSE") {
            return "Driver license identifier detected."
        }
        if upper.contains("MRN") || upper.contains("PATIENT ID") {
            return "Medical/patient identifier text detected."
        }
        if upper.contains("SSN") {
            return "Social security number pattern detected."
        }
        return "Sensitive text pattern detected."
    }

    private func hasLeakInsight(for label: String) -> Bool {
        let upper = label.uppercased()
        return upper.contains("FACE")
            || upper.contains("BADGE")
            || upper.contains("BARCODE")
            || upper.contains("DOB")
            || upper.contains("BIRTH")
            || upper.contains("EXPIRATION")
            || upper.contains("MRN")
            || upper.contains("PATIENT ID")
            || upper.contains("PHONE")
            || upper.contains("EMAIL")
            || upper.contains("DRIVER LICENSE")
            || upper.contains("SSN")
    }
}

private struct LeakInsightOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]
    let selectedCategory: String?
    let selectedRegionID: UUID?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedAnnotations) { annotation in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.red, lineWidth: 2.2)
                    .frame(width: annotation.rect.width, height: annotation.rect.height)
                    .position(x: annotation.rect.midX, y: annotation.rect.midY)

                Path { path in
                    path.move(to: annotation.anchor)
                    path.addQuadCurve(to: annotation.badgeAnchor, control: annotation.control)
                }
                .stroke(Color.red.opacity(0.88), lineWidth: 1.8)

                Text(annotation.message)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .position(x: annotation.badgeRect.midX, y: annotation.badgeRect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private var positionedAnnotations: [LeakAnnotation] {
        var reserved: [CGRect] = []
        var output: [LeakAnnotation] = []
        var labelCounts: [String: Int] = [:]
        for region in filteredRegions {
            guard let mapped = mapRegion(region) else { continue }
            let normalized = region.label.uppercased()
            labelCounts[normalized, default: 0] += 1
            let index = labelCounts[normalized] ?? 1
            let message = leakMessage(for: region.label, index: index)
            guard !message.isEmpty else { continue }

            let badgeWidth = min(250, max(130, CGFloat(message.count * 5 + 24)))
            let badgeHeight: CGFloat = 30
            let proposed = CGRect(
                x: min(max(mapped.maxX + 8, 8), max(8, containerSize.width - badgeWidth - 8)),
                y: max(8, mapped.minY - 12),
                width: badgeWidth,
                height: badgeHeight
            )
            var badgeRect = proposed
            var attempts = 0
            while reserved.contains(where: { $0.intersects(badgeRect.insetBy(dx: -2, dy: -2)) }) && attempts < 20 {
                attempts += 1
                badgeRect.origin.y = min(containerSize.height - badgeHeight - 8, badgeRect.origin.y + badgeHeight + 4)
            }
            reserved.append(badgeRect)

            let anchor = CGPoint(x: mapped.maxX, y: mapped.midY)
            let badgeAnchor = CGPoint(x: badgeRect.minX, y: badgeRect.midY)
            let control = CGPoint(x: anchor.x + max(10, (badgeAnchor.x - anchor.x) * 0.45), y: (anchor.y + badgeAnchor.y) / 2)
            output.append(
                LeakAnnotation(
                    id: region.id,
                    rect: mapped,
                    message: message,
                    badgeRect: badgeRect,
                    anchor: anchor,
                    badgeAnchor: badgeAnchor,
                    control: control
                )
            )
        }
        return output
    }

    private var filteredRegions: [RedactionRegion] {
        var working = regions
        if let selectedCategory {
            working = working.filter { category(for: $0.label) == selectedCategory }
        }
        if let selectedRegionID {
            working = working.filter { $0.id == selectedRegionID }
        }
        return working
    }

    private func mapRegion(_ region: RedactionRegion) -> CGRect? {
        let mapped = CoordinateMapper.mapImageRect(
            region.rect,
            imageSize: imageSize,
            containerSize: containerSize,
            padding: 2
        )
        guard mapped != .zero else { return nil }
        return mapped
    }

    private func leakMessage(for label: String, index: Int) -> String {
        let upper = label.uppercased()
        if upper.contains("FACE") { return "FACE #\(index): Visible face can reveal identity." }
        if upper.contains("BADGE PHOTO") { return "BADGE PHOTO #\(index): Workplace identity may be exposed." }
        if upper.contains("BADGE") || upper.contains("BARCODE") { return "BADGE INFO #\(index): Badge identifiers can expose staff details." }
        if upper.contains("DOB") || upper.contains("BIRTH") { return "DOB #\(index): Can be used for identity verification." }
        if upper.contains("EXPIRATION") { return "EXPIRATION DATE #\(index): Can validate linked IDs." }
        if upper.contains("MRN") || upper.contains("PATIENT ID") { return "PATIENT ID #\(index): Can link to medical records." }
        if upper.contains("PHONE") || upper.contains("EMAIL") { return "CONTACT #\(index): Can enable phishing." }
        if upper.contains("DRIVER LICENSE") { return "DRIVER LICENSE #\(index): Can enable credential abuse." }
        if upper.contains("SSN") { return "SSN #\(index): Can enable identity theft." }
        return ""
    }

    private func category(for label: String) -> String {
        let upper = label.uppercased()
        if upper.contains("FACE") { return "FACE" }
        if upper.contains("BADGE") || upper.contains("BARCODE") { return "BADGE" }
        if upper.contains("DOB") || upper.contains("DATE OF BIRTH") { return "DOB" }
        if upper.contains("EXPIRATION") { return "EXPIRATION" }
        if upper.contains("MRN") || upper.contains("PATIENT ID") { return "PATIENT ID" }
        if upper.contains("PHONE") || upper.contains("EMAIL") { return "CONTACT" }
        if upper.contains("DRIVER LICENSE") { return "DRIVER LICENSE" }
        if upper.contains("SSN") { return "SSN" }
        return "OTHER"
    }
}

private struct LeakAnnotation: Identifiable {
    let id: UUID
    let rect: CGRect
    let message: String
    let badgeRect: CGRect
    let anchor: CGPoint
    let badgeAnchor: CGPoint
    let control: CGPoint
}

private extension RedactionRegion {
    var displayCategory: String {
        switch type {
        case .phiText, .object:
            return label.displayTitle
        case .face:
            return "Face"
        case .unknown:
            return label.isEmpty ? "Sensitive region" : label.displayTitle
        }
    }
}

private extension String {
    var displayTitle: String {
        replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}
