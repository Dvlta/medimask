import SwiftUI
import Foundation

struct DetectionOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]
    var selectedCategory: String? = nil
    var selectedRegionID: UUID? = nil
    var zoomScale: CGFloat = 1.0
    var onCategoryTap: ((String) -> Void)? = nil

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
                Group {
                    if selectedCategory == nil {
                        Button(overlayDisplayLabel(for: overlay.label)) {
                            onCategoryTap?(overlay.label)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(overlayDisplayLabel(for: overlay.label))
                    }
                }
                .font(.system(size: labelFontSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(1.0)
                .foregroundStyle(.white)
                .padding(.horizontal, horizontalPadding)
                .frame(width: badge.width, height: badge.height, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(overlay.color)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .position(x: badge.midX, y: badge.midY)
            }
        }
    }

    private var displayRegions: [OverlayRegion] {
        let filteredByCategory = selectedCategory == nil ? regions : regions.filter { region in
            category(for: region.label) == selectedCategory
        }

        let filteredByID = selectedRegionID == nil ? filteredByCategory : filteredByCategory.filter { region in
            region.id == selectedRegionID
        }

        if selectedCategory == nil {
            let grouped = Dictionary(grouping: filteredByID) { category(for: $0.label) }
            return grouped.compactMap { category, group in
                let unionRect = group.map(\.rect).reduce(CGRect.null) { partial, rect in
                    partial.isNull ? rect : partial.union(rect)
                }
                guard !unionRect.isNull else { return nil }

                let regionType = dominantType(for: group)
                return mappedOverlayRect(id: group.first?.id ?? UUID(), rect: unionRect, label: category, type: regionType)
            }
        }

        return filteredByID.compactMap { region in
            mappedOverlayRect(id: region.id, rect: region.rect, label: region.label, type: region.type)
        }
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

    private func badgeFrame(for overlay: OverlayRegion, reserved: inout [CGRect]) -> CGRect {
        let label = overlayDisplayLabel(for: overlay.label)
        let fontSize = labelFontSize
        let labelWidth = CGFloat(label.count) * fontSize * 0.54 + 12 + horizontalPadding * 2
        let width = min(
            containerSize.width - 8,
            max(minBadgeWidth, min(maxBadgeWidth, max(overlay.rect.width * 0.72, labelWidth)))
        )
        let charsPerLine = max(8, Int(width / max(fontSize * 0.56, 1)))
        let lineCount = max(1, Int(ceil(Double(label.count) / Double(charsPerLine))))
        let height: CGFloat = max(minBadgeHeight, CGFloat(min(maxLabelLines, lineCount)) * (fontSize + 2) + 6)
        let minX = max(2, min(overlay.rect.minX + 2, containerSize.width - width - 2))
        var candidate = CGRect(x: minX, y: max(2, overlay.rect.minY - height - 2), width: width, height: height)

        let maxY = max(2, containerSize.height - height - 2)
        let step: CGFloat = height + 6
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

    private func category(for label: String) -> String {
        let upper = label.uppercased()
        if upper.contains("BADGE") || upper.contains("BARCODE") || upper.contains("LICENSE") || upper.contains("STAFF") {
            return "BADGE"
        }
        if upper.contains("FACE") {
            return "FACE"
        }
        if upper.contains("PHONE") || upper.contains("EMAIL") || upper.contains("ADDRESS") {
            return "CONTACT"
        }
        if upper.contains("DATE") {
            return "DATES"
        }
        if upper.contains("MRN") || upper.contains("PATIENT") || upper.contains("INSURANCE") || upper.contains("SSN") {
            return "PATIENT IDs"
        }
        return "OTHER"
    }

    private func overlayDisplayLabel(for label: String) -> String {
        return label
    }

    private func indexedLabel(base: String, index: Int) -> String {
        "\(base) #\(index)"
    }

    private var maxLabelLines: Int {
        1
    }

    private var labelFontSize: CGFloat {
        // Aggressive precision mode: zoom in => much smaller labels.
        if zoomScale <= 1.0 { return 11.0 }
        return max(6.0, 10.0 / min(3.0, zoomScale * 1.35))
    }

    private var horizontalPadding: CGFloat {
        zoomScale > 1.08 ? 2 : 6
    }

    private var minBadgeWidth: CGFloat {
        zoomScale > 1.08 ? 52 : 96
    }

    private var maxBadgeWidth: CGFloat {
        zoomScale > 1.08 ? containerSize.width * 0.26 : containerSize.width * 0.72
    }

    private var minBadgeHeight: CGFloat {
        zoomScale > 1.08 ? 14 : 24
    }

    private var boxLineWidth: CGFloat {
        zoomScale > 1.08 ? 1.2 : 2.8
    }

    private var boxDashLength: CGFloat {
        zoomScale > 1.08 ? 5 : 10
    }

    private var boxDashGap: CGFloat {
        zoomScale > 1.08 ? 2 : 4
    }

    private var mappedRegions: [OverlayRegion] {
        regions.compactMap { region in
            let mappedRect = CoordinateMapper.mapImageRect(
                region.rect,
                imageSize: imageSize,
                containerSize: containerSize,
                padding: 2
            )
            guard mappedRect != .zero else { return nil }
            return OverlayRegion(
                id: region.id,
                rect: mappedRect,
                label: region.label,
                color: color(for: region.type),
                badgeRect: .zero
            )
        }
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
