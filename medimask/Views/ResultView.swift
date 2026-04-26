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

private enum OutputStyle: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case insight = "Insight"

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
    @State private var outputStyle: OutputStyle = .clean
    @State private var selectedLeakCategory: String?
    @State private var selectedLeakRegionID: UUID?

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
                                selectedRegionID: selectedLeakRegionID,
                                zoomScale: zoom.scale
                            )
                        }
                    }
                    .scaleEffect(zoom.scale, anchor: .center)
                    .offset(x: zoom.offset.width, y: zoom.offset.height)
                    .animation(.spring(response: 0.3, dampingFraction: 0.86), value: selectedLeakCategory)
                    .animation(.spring(response: 0.3, dampingFraction: 0.86), value: selectedLeakRegionID)

                    if selectedTab == .scrubbed,
                       outputStyle == .insight,
                       (selectedLeakCategory != nil || selectedLeakRegionID != nil) {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                    selectedLeakCategory = nil
                                    selectedLeakRegionID = nil
                                }
                            } label: {
                                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(iceDark)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(iceLight))
                            }
                            .padding(10)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        imageFullscreen = true
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            .frame(height: 360)
            .clipped()
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

            if selectedTab == .scrubbed {
                HStack(spacing: 0) {
                    ForEach(OutputStyle.allCases) { style in
                        iceToggleButton(title: style.rawValue, isSelected: outputStyle == style) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                outputStyle = style
                                selectedLeakCategory = nil
                                selectedLeakRegionID = nil
                            }
                        }
                    }
                }
                .padding(4)
                .background(Capsule().fill(frostWhite.opacity(0.06)))
                .padding(.horizontal, 24)
            }

            if selectedTab == .scrubbed, outputStyle == .insight {
                leakFilterPanel
            }
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
                Text(descriptionForLabel(region.label))
                    .font(.system(size: 11))
                    .foregroundColor(frostWhite.opacity(0.44))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        let labels = Array(Set(effectiveRegions.map(\.label))).sorted()
        guard !labels.isEmpty else {
            return ["No high-risk identifiers were detected in this scan."]
        }
        return labels.map { "\($0.displayTitle) was detected and selected for blurring." }
    }

    private var leakFilterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Leak Topics")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .foregroundColor(frostWhite.opacity(0.72))
                Spacer()
                Text("Tap to zoom")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(frostWhite.opacity(0.32))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    leakChip("ALL", isSelected: selectedLeakCategory == nil) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            selectedLeakCategory = nil
                            selectedLeakRegionID = nil
                        }
                    }

                    ForEach(leakCategories, id: \.self) { category in
                        leakChip(category, isSelected: selectedLeakCategory == category) {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
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
                                isSelected: selectedLeakRegionID == region.id,
                                multiline: true
                            ) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                    selectedLeakRegionID = selectedLeakRegionID == region.id ? nil : region.id
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(iceCard.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(iceTeal.opacity(0.10), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func leakChip(
        _ title: String,
        isSelected: Bool,
        multiline: Bool = false,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: multiline ? 11 : 12, weight: .bold))
                .tracking(multiline ? 0 : 0.3)
                .lineLimit(multiline ? 2 : 1)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.8)
                .frame(
                    minWidth: multiline ? 112 : nil,
                    idealWidth: multiline ? 138 : nil,
                    maxWidth: multiline ? 166 : nil,
                    alignment: .leading
                )
                .padding(.horizontal, multiline ? 10 : 12)
                .padding(.vertical, multiline ? 8 : 7)
                .foregroundColor(isSelected ? iceDark : frostWhite.opacity(0.58))
                .background(
                    RoundedRectangle(cornerRadius: multiline ? 10 : 999, style: .continuous)
                        .fill(isSelected ? iceLight : frostWhite.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: multiline ? 10 : 999, style: .continuous)
                                .strokeBorder(isSelected ? iceLight.opacity(0.0) : iceTeal.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var leakCategories: [String] {
        Array(leakGroupedRegions.keys).sorted()
    }

    private var leakGroupedRegions: [String: [RedactionRegion]] {
        Dictionary(grouping: effectiveRegions) { displayLabel(for: $0.label) }
    }

    private func displayLabel(for label: String) -> String {
        label.isEmpty ? "Sensitive Region" : label.displayTitle
    }

    private func leakFocusRect() -> CGRect? {
        let selected: [RedactionRegion]
        if let selectedLeakRegionID {
            selected = effectiveRegions.filter { $0.id == selectedLeakRegionID }
        } else if let selectedLeakCategory {
            selected = effectiveRegions.filter { displayLabel(for: $0.label) == selectedLeakCategory }
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
        return (scale, CGSize(width: (center.x - target.x) * scale, height: (center.y - target.y) * scale))
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

    private func descriptionForLabel(_ label: String) -> String {
        "\(displayLabel(for: label)) was detected by the pipeline."
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
            return "doc.text.fill"
        }
    }
}

private struct LeakInsightOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]
    let selectedCategory: String?
    let selectedRegionID: UUID?
    let zoomScale: CGFloat

    private let iceDark = Color(red: 0.05, green: 0.12, blue: 0.15)
    private let iceLight = Color(red: 0.55, green: 0.82, blue: 0.85)
    private let frozenRed = Color(red: 0.85, green: 0.35, blue: 0.38)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedAnnotations) { annotation in
                RoundedRectangle(cornerRadius: showsMessages ? 8 : 5, style: .continuous)
                    .stroke(frozenRed, lineWidth: boxLineWidth)
                    .frame(
                        width: indicatorRect(for: annotation.rect).width,
                        height: indicatorRect(for: annotation.rect).height
                    )
                    .position(x: annotation.rect.midX, y: annotation.rect.midY)

                if showsMessages {
                    Text(annotation.message)
                        .font(.system(size: snappedLabelFontSize, weight: .semibold))
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .foregroundColor(iceDark)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(width: annotation.badgeRect.width, height: annotation.badgeRect.height)
                        .background(iceLight.opacity(0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .clipped()
                        .position(x: annotation.badgeRect.midX, y: annotation.badgeRect.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var showsMessages: Bool {
        selectedCategory != nil || selectedRegionID != nil
    }

    private var zoomCompression: CGFloat {
        guard zoomScale > 1 else { return 1.0 }
        return max(0.12, 1.0 / pow(zoomScale, 2.35))
    }

    private var labelFontSize: CGFloat {
        max(3.8, 13.2 * zoomCompression)
    }

    private var snappedLabelFontSize: CGFloat {
        max(4.0, round(labelFontSize * 2) / 2)
    }

    private var horizontalPadding: CGFloat {
        max(0.5, 6 * zoomCompression)
    }

    private var verticalPadding: CGFloat {
        max(0.5, 3 * zoomCompression)
    }

    private var minBadgeWidth: CGFloat {
        max(18, 96 * zoomCompression)
    }

    private var maxBadgeWidth: CGFloat {
        containerSize.width * max(0.08, 0.72 * zoomCompression)
    }

    private var minBadgeHeight: CGFloat {
        max(7, 24 * zoomCompression)
    }

    private var boxLineWidth: CGFloat {
        showsMessages ? max(0.35, 2.8 * zoomCompression) : 2.2
    }

    private var regionBoxScale: CGFloat {
        showsMessages ? max(0.2, zoomCompression * 0.75) : 1.0
    }

    private func indicatorRect(for rect: CGRect) -> CGSize {
        if showsMessages {
            return CGSize(width: rect.width * regionBoxScale, height: rect.height * regionBoxScale)
        }

        return CGSize(
            width: max(16, min(42, rect.width * 0.42)),
            height: max(10, min(30, rect.height * 0.42))
        )
    }

    private var positionedAnnotations: [LeakAnnotation] {
        var reserved: [CGRect] = []
        var output: [LeakAnnotation] = []
        var labelCounts: [String: Int] = [:]

        for item in leakDisplayItems {
            let normalized = item.label.uppercased()
            labelCounts[normalized, default: 0] += 1
            let index = labelCounts[normalized] ?? 1
            let message = leakMessage(for: item.label, index: index)
            guard !message.isEmpty else { continue }

            let badgeRect = badgeFrame(for: message, mappedRect: item.mappedRect, reserved: &reserved)
            reserved.append(badgeRect)
            output.append(
                LeakAnnotation(
                    id: item.id,
                    rect: item.mappedRect,
                    message: message,
                    badgeRect: badgeRect
                )
            )
        }

        return output
    }

    private var leakDisplayItems: [LeakDisplayItem] {
        filteredRegions.compactMap { region -> LeakDisplayItem? in
            guard let mapped = mapRegion(region) else { return nil }
            return LeakDisplayItem(id: region.id, label: region.label, mappedRect: mapped)
        }
    }

    private var filteredRegions: [RedactionRegion] {
        var working = regions
        if let selectedCategory {
            working = working.filter { displayLabel(for: $0.label) == selectedCategory }
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

    private func badgeFrame(for message: String, mappedRect: CGRect, reserved: inout [CGRect]) -> CGRect {
        let fontSize = snappedLabelFontSize
        let labelWidth = CGFloat(message.count) * fontSize * 0.54 + 12 + horizontalPadding * 2
        let width = min(
            containerSize.width - 8,
            max(minBadgeWidth, min(maxBadgeWidth, max(mappedRect.width * 0.72 * zoomCompression, labelWidth)))
        )
        let charsPerLine = max(8, Int(width / max(fontSize * 0.56, 1)))
        let lineCount = max(1, Int(ceil(Double(message.count) / Double(charsPerLine))))
        let lineHeight = fontSize + 1.6
        let dynamicHeight = CGFloat(lineCount) * lineHeight + verticalPadding * 2 + 4
        let maxAllowedHeight = max(14, containerSize.height * 0.65)
        let height = min(maxAllowedHeight, max(minBadgeHeight, dynamicHeight))
        let minX = max(2, min(mappedRect.minX + 2, containerSize.width - width - 2))
        var candidate = CGRect(x: minX, y: max(2, mappedRect.minY - height - 2), width: width, height: height)

        let maxY = max(2, containerSize.height - height - 2)
        let step = height + 6
        var attempts = 0
        while reserved.contains(where: { $0.intersects(candidate.insetBy(dx: -3, dy: -3)) }) && attempts < 36 {
            attempts += 1
            let nextY = candidate.minY + step
            candidate.origin.y = nextY <= maxY ? nextY : 2
        }

        return candidate
    }

    private func leakMessage(for label: String, index: Int) -> String {
        "\(displayLabel(for: label)) #\(index)"
    }

    private func displayLabel(for label: String) -> String {
        label.isEmpty ? "Sensitive Region" : label.displayTitle
    }
}

private struct LeakAnnotation: Identifiable {
    let id: UUID
    let rect: CGRect
    let message: String
    let badgeRect: CGRect
}

private struct LeakDisplayItem {
    let id: UUID
    let label: String
    let mappedRect: CGRect
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
