import SwiftUI

struct DetectionOverlayView: View {
    let imageSize: CGSize
    let containerSize: CGSize
    let regions: [RedactionRegion]

    var body: some View {
        Canvas { context, _ in
            for region in regions {
                let mappedRect = CoordinateMapper.mapImageRect(
                    region.rect,
                    imageSize: imageSize,
                    containerSize: containerSize,
                    padding: 2
                )
                guard mappedRect != .zero else { continue }

                let path = Path(roundedRect: mappedRect, cornerRadius: 8)
                let regionColor = color(for: region.type)
                context.stroke(path, with: .color(regionColor), lineWidth: 2.5)

                context.fill(
                    path,
                    with: .color(regionColor.opacity(0.12))
                )

                let text = Text(region.label)
                    .font(.caption.bold())
                    .foregroundColor(.white)

                let badgeWidth = min(max(56, mappedRect.width), 140)
                let preferredY = mappedRect.minY - 24
                let badgeY = max(0, preferredY)
                let badgeRect = CGRect(
                    x: mappedRect.minX,
                    y: badgeY,
                    width: badgeWidth,
                    height: 20
                )
                let textPoint = CGPoint(x: badgeRect.minX + 8, y: badgeRect.minY + 4)
                context.fill(Path(roundedRect: badgeRect, cornerRadius: 6), with: .color(regionColor))
                context.draw(text, at: textPoint, anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }

    private func color(for type: RegionType) -> Color {
        switch type {
        case .face:
            return .yellow
        case .phiText:
            return .red
        case .object:
            return .blue
        case .unknown:
            return .gray
        }
    }
}
