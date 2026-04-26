import SwiftUI
import Foundation

struct DetectionOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]
    var selectedCategory: String?
    var selectedRegionID: UUID?
    var zoomScale: CGFloat
    var onCategoryTap: ((String) -> Void)?

    init(
        imageSize: CGSize,
        containerSize: CGSize,
        regions: [RedactionRegion],
        selectedCategory: String? = nil,
        selectedRegionID: UUID? = nil,
        zoomScale: CGFloat = 1.0,
        onCategoryTap: ((String) -> Void)? = nil
    ) {
        self.imageSize = imageSize
        self.containerSize = containerSize
        self.regions = regions
        self.selectedCategory = selectedCategory
        self.selectedRegionID = selectedRegionID
        self.zoomScale = zoomScale
        self.onCategoryTap = onCategoryTap
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedRegions) { overlay in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        overlay.color,
                        style: StrokeStyle(
                            lineWidth: boxLineWidth,
                            dash: [boxDashLength, boxDashGap]
                        )
                    )
                    .frame(width: overlay.rect.width, height: overlay.rect.height)
                    .position(x: overlay.rect.midX, y: overlay.rect.midY)

                let badge = overlay.badgeRect
                Button {
                    onCategoryTap?(displayLabel(for: overlay.label))
                } label: {
                    Text(overlayDisplayLabel(for: overlay.label))
                        .font(.system(size: snappedLabelFontSize, weight: .semibold))
                        .lineLimit(nil)
                        .minimumScaleFactor(1.0)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(width: badge.width, height: badge.height, alignment: .center)
                        .background(overlay.color.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .clipped()
                }
                .buttonStyle(.plain)
                .position(x: badge.midX, y: badge.midY)
                .disabled(onCategoryTap == nil)
            }
        }
    }

    private var displayRegions: [OverlayRegion] {
        let filteredByCategory = selectedCategory == nil ? regions : regions.filter { region in
            displayLabel(for: region.label) == selectedCategory
        }

        let filteredByID = selectedRegionID == nil ? filteredByCategory : filteredByCategory.filter { region in
            region.id == selectedRegionID
        }

        if selectedCategory == nil {
            let grouped = Dictionary(grouping: filteredByID) { displayLabel(for: $0.label) }
            return grouped.compactMap { category, group in
                let unionRect = group.map(\.rect).reduce(CGRect.null) { partial, rect in
                    partial.isNull ? rect : partial.union(rect)
                }
                guard !unionRect.isNull else { return nil }
                return mappedOverlayRect(
                    id: group.first?.id ?? UUID(),
                    rect: unionRect,
                    label: category,
                    type: dominantType(for: group)
                )
            }
        }

        return filteredByID.compactMap { region in
            mappedOverlayRect(id: region.id, rect: region.rect, label: region.label, type: region.type)
        }
    }

    private var positionedRegions: [OverlayRegion] {
        var output: [OverlayRegion] = []
        var reservedBadgeFrames: [CGRect] = []
        var perLabelCounter: [String: Int] = [:]

        for region in displayRegions.sorted(by: { $0.rect.minY < $1.rect.minY }) {
            perLabelCounter[region.label, default: 0] += 1
            let index = perLabelCounter[region.label] ?? 1
            let badge = badgeFrame(for: region, reserved: &reservedBadgeFrames)
            output.append(
                OverlayRegion(
                    id: region.id,
                    rect: region.rect,
                    label: indexedLabel(base: region.label, index: index),
                    color: region.color,
                    badgeRect: badge
                )
            )
        }

        return output
    }

    private func mappedOverlayRect(id: UUID, rect: CGRect, label: String, type: RegionType) -> OverlayRegion? {
        let mappedRect = CoordinateMapper.mapImageRect(
            rect,
            imageSize: imageSize,
            containerSize: containerSize,
            padding: 2
        )
        guard mappedRect != .zero else { return nil }
        return OverlayRegion(
            id: id,
            rect: mappedRect,
            label: label,
            color: color(for: type),
            badgeRect: .zero
        )
    }

    private func badgeFrame(for overlay: OverlayRegion, reserved: inout [CGRect]) -> CGRect {
        let label = overlayDisplayLabel(for: overlay.label)
        let fontSize = snappedLabelFontSize
        let labelWidth = CGFloat(label.count) * fontSize * 0.52 + 12 + horizontalPadding * 2
        let width = min(
            containerSize.width - 6,
            max(minBadgeWidth, min(maxBadgeWidth, max(overlay.rect.width * 0.72, labelWidth)))
        )
        let charsPerLine = max(6, Int(width / max(fontSize * 0.54, 1)))
        let lineCount = max(1, Int(ceil(Double(label.count) / Double(charsPerLine))))
        let lineHeight = fontSize + 1.4
        let dynamicHeight = CGFloat(lineCount) * lineHeight + verticalPadding * 2 + 6
        let maxAllowedHeight = max(22, containerSize.height * 0.85)
        let height = min(maxAllowedHeight, max(minBadgeHeight, dynamicHeight))
        let minX = max(2, min(overlay.rect.minX + 2, containerSize.width - width - 2))
        var candidate = CGRect(x: minX, y: max(2, overlay.rect.minY - height - 2), width: width, height: height)

        let maxY = max(2, containerSize.height - height - 2)
        let step = height + 6
        var attempts = 0
        while reserved.contains(where: { $0.intersects(candidate.insetBy(dx: -3, dy: -3)) }) && attempts < 36 {
            attempts += 1
            let nextY = candidate.minY + step
            candidate.origin.y = nextY <= maxY ? nextY : 2
        }

        reserved.append(candidate)
        return candidate
    }

    private func dominantType(for regions: [RedactionRegion]) -> RegionType {
        if regions.contains(where: { $0.type == .face }) { return .face }
        if regions.contains(where: { $0.type == .object }) { return .object }
        if regions.contains(where: { $0.type == .phiText }) { return .phiText }
        return .unknown
    }

    private func displayLabel(for label: String) -> String {
        label.isEmpty ? "Sensitive Region" : label.displayTitle
    }

    private func overlayDisplayLabel(for label: String) -> String {
        label
    }

    private func indexedLabel(base: String, index: Int) -> String {
        selectedCategory == nil ? base : "\(base) #\(index)"
    }

    private var isFocusedZoom: Bool {
        zoomScale > 1.02 && (selectedCategory != nil || selectedRegionID != nil)
    }

    private var labelFontSize: CGFloat {
        if !isFocusedZoom { return 11.0 }
        return max(5.2, 9.0 / min(3.6, zoomScale * 1.95))
    }

    private var snappedLabelFontSize: CGFloat {
        max(5.0, round(labelFontSize * 2) / 2)
    }

    private var horizontalPadding: CGFloat {
        isFocusedZoom ? 2 : 6
    }

    private var verticalPadding: CGFloat {
        isFocusedZoom ? 2 : 4
    }

    private var minBadgeWidth: CGFloat {
        isFocusedZoom ? 44 : 86
    }

    private var maxBadgeWidth: CGFloat {
        isFocusedZoom ? containerSize.width * 0.42 : containerSize.width * 0.70
    }

    private var minBadgeHeight: CGFloat {
        isFocusedZoom ? 12 : 24
    }

    private var boxLineWidth: CGFloat {
        isFocusedZoom ? 0.95 : 2.8
    }

    private var boxDashLength: CGFloat {
        isFocusedZoom ? 3 : 10
    }

    private var boxDashGap: CGFloat {
        isFocusedZoom ? 1.5 : 4
    }

    private func color(for type: RegionType) -> Color {
        switch type {
        case .face:
            return Color(red: 0.92, green: 0.66, blue: 0.12)
        case .phiText:
            return Color(red: 0.83, green: 0.22, blue: 0.25)
        case .object:
            return Color(red: 0.16, green: 0.44, blue: 0.82)
        case .unknown:
            return .gray
        }
    }
}

private struct OverlayRegion: Identifiable {
    let id: UUID
    let rect: CGRect
    let label: String
    let color: Color
    let badgeRect: CGRect
}

private extension String {
    var displayTitle: String {
        replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}
