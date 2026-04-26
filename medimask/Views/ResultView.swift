import SwiftUI
import UIKit

private enum RegionSelectionAction: String, CaseIterable, Identifiable {
    case blur = "BLUR"
    case keep = "SHOW"

    var id: String { rawValue }
}

private enum ResultTab: String, CaseIterable, Identifiable {
    case original = "Original"
    case scrubbed = "Scrubbed"

    var id: String { rawValue }
}

struct ResultView: View {
    @Environment(\.dismiss) private var dismiss

    let result: DetectionResult

    @State private var selectedTab: ResultTab = .scrubbed
    @State private var isShowingShareSheet = false
    @State private var redactionMode: RedactionIntensityMode = .balanced
    @State private var regionSelections: [UUID: RegionSelectionAction] = [:]
    @State private var customizedImage: UIImage?
    @State private var saveConfirmation = false
    @State private var appearAnimation = false
    @State private var imageFullscreen = false
    @State private var snowPhase: CGFloat = 0

    private let imageRedactor = ImageRedactor()

    private let iceTeal = Color(red: 0.31, green: 0.69, blue: 0.72)
    private let iceLight = Color(red: 0.55, green: 0.82, blue: 0.85)
    private let iceDark = Color(red: 0.05, green: 0.12, blue: 0.15)
    private let iceMid = Color(red: 0.08, green: 0.18, blue: 0.22)
    private let frostWhite = Color(red: 0.85, green: 0.95, blue: 0.97)
    private let iceCard = Color(red: 0.07, green: 0.16, blue: 0.20)
    private let frozenRed = Color(red: 0.85, green: 0.35, blue: 0.38)
    private let frozenGreen = Color(red: 0.3, green: 0.78, blue: 0.65)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [iceDark, iceMid, iceDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            snowfall

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    imageHeader
                    controlsSection
                        .padding(.top, 24)
                    shareSection
                        .padding(.top, 28)
                    summarySection
                        .padding(.top, 28)
                    leakSection
                        .padding(.top, 20)
                    timingSection
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }

            if imageFullscreen {
                fullscreenImageOverlay
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: [customizedImage ?? result.scrubbedImage])
        }
        .onAppear {
            configureDefaults()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appearAnimation = true
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                snowPhase = 1
            }
        }
        .onChange(of: redactionMode) { _, _ in regenerateImage() }
        .onChange(of: regionSelections) { _, _ in regenerateImage() }
    }

    private var snowfall: some View {
        GeometryReader { geo in
            ForEach(0..<12, id: \.self) { i in
                let seed = Double(i) * 1.618
                let x = seed.truncatingRemainder(dividingBy: 1.0)
                let speed = 0.2 + Double(i % 4) * 0.1
                let size = CGFloat(1 + i % 3)
                Circle()
                    .fill(frostWhite.opacity(speed * 0.35))
                    .frame(width: size, height: size)
                    .position(
                        x: geo.size.width * CGFloat(x) + sin(Double(snowPhase) * .pi * 2 + seed * 3) * 10,
                        y: geo.size.height * CGFloat(
                            (Double(snowPhase) * speed + seed).truncatingRemainder(dividingBy: 1.0)
                        )
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var imageHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(frostWhite.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(frostWhite)
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("RESULT")
                        .font(.system(size: 20, weight: .heavy).width(.compressed))
                        .scaleEffect(x: 0.8, y: 1.3)
                        .tracking(3)
                        .foregroundColor(frostWhite)
                    Text("Safe-to-share copy created")
                        .font(.system(size: 12))
                        .foregroundColor(frostWhite.opacity(0.48))
                }

                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)

            ZStack {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 360)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            imageFullscreen = true
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(iceCard.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(iceTeal.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: iceTeal.opacity(0.12), radius: 22, x: 0, y: 12)
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                iceToggleButton(title: "Original", isSelected: selectedTab == .original) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = .original
                    }
                }
                iceToggleButton(title: "Scrubbed", isSelected: selectedTab == .scrubbed) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = .scrubbed
                    }
                }
            }
            .padding(4)
            .background(Capsule().fill(frostWhite.opacity(0.06)))
            .padding(.horizontal, 24)
        }
        .opacity(appearAnimation ? 1 : 0)
    }

    private func iceToggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? iceDark : frostWhite.opacity(0.4))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [iceTeal, iceLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                )
        }
    }

    private var fullscreenImageOverlay: some View {
        ZStack {
            iceDark.ignoresSafeArea()

            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)

            VStack {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            imageFullscreen = false
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(frostWhite.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(frostWhite)
                        }
                    }

                    Spacer()

                    HStack(spacing: 0) {
                        iceToggleButton(title: "Original", isSelected: selectedTab == .original) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedTab = .original
                            }
                        }
                        iceToggleButton(title: "Scrubbed", isSelected: selectedTab == .scrubbed) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedTab = .scrubbed
                            }
                        }
                    }
                    .padding(3)
                    .background(Capsule().fill(frostWhite.opacity(0.08)))

                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Redaction Controls")
                .font(.system(size: 18, weight: .heavy).width(.condensed))
                .foregroundColor(frostWhite)

            HStack(spacing: 10) {
                modeButton(.balanced)
                modeButton(.highPrivacy)
            }

            HStack(spacing: 10) {
                iceQuickButton(title: "BLUR ALL", icon: "eye.slash") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        setAllSelections(.blur)
                    }
                }
                iceQuickButton(title: "KEEP ALL", icon: "eye") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        setAllSelections(.keep)
                    }
                }
            }

            VStack(spacing: 2) {
                ForEach(selectableRegions) { region in
                    regionRow(for: region)
                }
            }
        }
        .padding(.horizontal, 24)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    private func modeButton(_ mode: RedactionIntensityMode) -> some View {
        let isSelected = redactionMode == mode
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                redactionMode = mode
            }
        } label: {
            Text(mode.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(isSelected ? iceDark : frostWhite.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [iceTeal, iceLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            Capsule()
                                .fill(frostWhite.opacity(0.04))
                                .overlay(Capsule().strokeBorder(frostWhite.opacity(0.08), lineWidth: 1))
                        }
                    }
                )
        }
    }

    private func iceQuickButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(iceTeal.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(iceTeal.opacity(0.08))
                    .overlay(Capsule().strokeBorder(iceTeal.opacity(0.15), lineWidth: 1))
            )
        }
    }

    private func regionRow(for region: RedactionRegion) -> some View {
        let action = regionSelections[region.id] ?? .blur
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iceTeal.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon(for: region))
                    .font(.system(size: 14))
                    .foregroundColor(iceTeal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(region.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(frostWhite.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(regionSubtitle(for: region))
                    .font(.system(size: 11))
                    .foregroundColor(frostWhite.opacity(0.3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    regionSelections[region.id] = action == .blur ? .keep : .blur
                }
            } label: {
                Text(action.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(action == .blur ? iceDark : frostWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(action == .blur ? frozenRed : frostWhite.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(iceCard.opacity(0.5)))
    }

    private var shareSection: some View {
        HStack(spacing: 12) {
            Button {
                isShowingShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share Scrubbed\nImage")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(iceDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [iceTeal, iceLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: iceTeal.opacity(0.25), radius: 12, y: 4)
            }

            Button {
                UIImageWriteToSavedPhotosAlbum(customizedImage ?? result.scrubbedImage, nil, nil, nil)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    saveConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        saveConfirmation = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: saveConfirmation ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text(saveConfirmation ? "Saved!" : "Save Copy")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(frostWhite.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(frostWhite.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(frostWhite.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
        .opacity(appearAnimation ? 1 : 0)
    }

    private var summarySection: some View {
        iceInfoCard(title: "Detection Summary") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summaryLines, id: \.self) { line in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(iceTeal.opacity(line.hasPrefix("Total") ? 1 : 0.5))
                            .frame(width: 3, height: 12)
                        Text(line)
                            .font(.system(size: 13, weight: line.hasPrefix("Total") ? .semibold : .medium, design: .monospaced))
                            .foregroundColor(frostWhite.opacity(line.hasPrefix("Total") ? 0.7 : 0.6))
                    }
                }
            }
        }
    }

    private var leakSection: some View {
        iceInfoCard(title: "What This Data Could Leak") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(leakRiskLines, id: \.self) { line in
                    HStack(spacing: 8) {
                        Image(systemName: line.hasPrefix("No high-risk") ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(line.hasPrefix("No high-risk") ? frozenGreen : frozenRed.opacity(0.8))
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundColor(frostWhite.opacity(0.5))
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        iceInfoCard(title: "Processing Time") {
            VStack(alignment: .leading, spacing: 6) {
                timingRow(label: "Face detection", value: timingString(result.timings.faceDetectionMs))
                timingRow(label: "OCR", value: timingString(result.timings.ocrMs))
                timingRow(label: "PHI rules", value: timingString(result.timings.phiDetectionMs))
                timingRow(label: "Redaction", value: timingString(result.timings.redactionMs))
                timingRow(label: "Total", value: timingString(result.timings.totalMs))
            }
        }
    }

    private func iceInfoCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .heavy).width(.condensed))
                .foregroundColor(frostWhite)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(iceCard.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(iceTeal.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .opacity(appearAnimation ? 1 : 0)
    }

    private func timingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(frostWhite.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(iceTeal.opacity(0.8))
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

    private var summaryLines: [String] {
        let grouped = Dictionary(grouping: effectiveRegions, by: \.label)
        let sortedLabels = grouped.keys.sorted()
        if sortedLabels.isEmpty {
            return ["No detections found.", "Total regions: 0"]
        }

        return sortedLabels.map { label in
            "\(label): \(grouped[label]?.count ?? 0)"
        } + ["Total regions: \(effectiveRegions.count)"]
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

    private func setAllSelections(_ action: RegionSelectionAction) {
        var updated: [UUID: RegionSelectionAction] = [:]
        selectableRegions.forEach { updated[$0.id] = action }
        regionSelections = updated
    }

    private func timingString(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }

    private func regionSubtitle(for region: RedactionRegion) -> String {
        let detector = region.source
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        return "\(region.displayCategory) - \(detector)"
    }

    private func icon(for region: RedactionRegion) -> String {
        switch region.type {
        case .face:
            return "person.crop.circle.fill"
        case .object:
            return "barcode.viewfinder"
        case .unknown:
            return "shield.lefthalf.filled"
        case .phiText:
            if region.label.contains("DATE") {
                return "calendar"
            }
            if region.label.contains("LOCATION") || region.label.contains("ADDRESS") {
                return "mappin.circle"
            }
            if region.label.contains("PHONE") {
                return "phone.fill"
            }
            if region.label.contains("EMAIL") {
                return "envelope.fill"
            }
            if region.label.contains("PERSON") || region.label.contains("NAME") {
                return "person.fill"
            }
            return "doc.text.fill"
        }
    }
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
