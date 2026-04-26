import SwiftUI
import Foundation

struct DetectionOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]
    var selectedCategory: String? = nil

    var body: some View {
        let callouts = layoutCallouts()

        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for callout in callouts {
                    let boxPath = Path(roundedRect: callout.rect, cornerRadius: 8)
                    context.stroke(
                        boxPath,
                        with: .color(callout.color),
                        style: StrokeStyle(lineWidth: 3.2, dash: [10, 4])
                    )

                    let dotRect = CGRect(x: callout.anchor.x - 4, y: callout.anchor.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(callout.color))

                    var connector = Path()
                    connector.move(to: callout.anchor)
                    connector.addQuadCurve(
                        to: CGPoint(x: callout.badgeRect.minX, y: callout.badgeRect.midY),
                        control: callout.controlPoint
                    )
                    context.stroke(connector, with: .color(callout.color.opacity(0.92)), lineWidth: 2.0)
                }
            }

            ForEach(callouts) { callout in
                Text(callout.label)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(width: callout.badgeRect.width, height: callout.badgeRect.height, alignment: .leading)
                    .background(callout.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .position(x: callout.badgeRect.midX, y: callout.badgeRect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private var mappedRegions: [OverlayRegion] {
        let filtered = regions.filter { region in
            guard let selectedCategory else { return true }
            return category(for: region.label) == selectedCategory
        }

        let grouped = Dictionary(grouping: filtered, by: { category(for: $0.label) })
        return grouped.compactMap { category, group in
            let unionRect = group.map(\.rect).reduce(CGRect.null) { partial, rect in
                partial.isNull ? rect : partial.union(rect)
            }
            guard !unionRect.isNull else { return nil }

            let mappedRect = CoordinateMapper.mapImageRect(
                unionRect,
                imageSize: imageSize,
                containerSize: containerSize,
                padding: 2
            )
            guard mappedRect != .zero else { return nil }

            let dominantType = group.contains(where: { $0.type == .face }) ? RegionType.face :
                (group.contains(where: { $0.type == .object }) ? RegionType.object : .phiText)

            return OverlayRegion(
                id: group.first?.id ?? UUID(),
                rect: mappedRect,
                label: category,
                color: color(for: dominantType)
            )
        }
        .sorted { $0.rect.minY < $1.rect.minY }
    }

    private func layoutCallouts() -> [OverlayCallout] {
        let sorted = mappedRegions.sorted { $0.rect.minY < $1.rect.minY }
        var reservedFrames: [CGRect] = []
        var output: [OverlayCallout] = []

        for overlay in sorted {
            let badgeRect = placeBadge(for: overlay, reservedFrames: &reservedFrames)
            let anchor = CGPoint(x: overlay.rect.maxX, y: overlay.rect.midY)
            let controlPoint = CGPoint(
                x: anchor.x + max(12, (badgeRect.minX - anchor.x) * 0.42),
                y: (anchor.y + badgeRect.midY) / 2
            )
            output.append(
                OverlayCallout(
                    id: overlay.id,
                    rect: overlay.rect,
                    label: overlay.label,
                    color: overlay.color,
                    badgeRect: badgeRect,
                    anchor: anchor,
                    controlPoint: controlPoint
                )
            )
        }

        return output
    }

    private func placeBadge(for overlay: OverlayRegion, reservedFrames: inout [CGRect]) -> CGRect {
        let width = CGFloat(max(96, min(260, overlay.label.count * 7 + 22)))
        let height: CGFloat = 24
        let x = max(8, containerSize.width - width - 8)
        let maxY = max(6, containerSize.height - height - 6)
        let step = height + 6

        var y = max(6, min(overlay.rect.minY - 4, maxY))
        var candidate = CGRect(x: x, y: y, width: width, height: height)
        var attempts = 0
        let maxAttempts = max(1, Int((maxY - 6) / step) + 3)

        while reservedFrames.contains(where: { $0.intersects(candidate.insetBy(dx: -2, dy: -2)) }) {
            attempts += 1
            if attempts >= maxAttempts {
                break
            }

            y += step
            if y > maxY {
                y = 6
            }
            candidate = CGRect(x: x, y: y, width: width, height: height)
        }

        // Deterministic fallback: place in a stacked lane without looping.
        if reservedFrames.contains(where: { $0.intersects(candidate.insetBy(dx: -2, dy: -2)) }) {
            let slotCount = max(1, Int((maxY - 6) / step) + 1)
            let slot = reservedFrames.count % slotCount
            let fallbackY = min(maxY, 6 + CGFloat(slot) * step)
            candidate = CGRect(x: x, y: fallbackY, width: width, height: height)
        }

        reservedFrames.append(candidate)
        return candidate
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
}

private struct OverlayRegion: Identifiable {
    let id: UUID
    let rect: CGRect
    let label: String
    let color: Color
}

private struct OverlayCallout: Identifiable {
    let id: UUID
    let rect: CGRect
    let label: String
    let color: Color
    let badgeRect: CGRect
    let anchor: CGPoint
    let controlPoint: CGPoint
}
