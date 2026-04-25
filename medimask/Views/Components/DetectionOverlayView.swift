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
                    containerSize: containerSize
                )
                let path = Path(roundedRect: mappedRect, cornerRadius: 8)
                context.stroke(path, with: .color(color(for: region.type)), lineWidth: 2)

                let text = Text(region.label)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                let textPoint = CGPoint(x: mappedRect.minX + 6, y: mappedRect.minY + 6)

                let badgeRect = CGRect(x: mappedRect.minX, y: mappedRect.minY, width: max(48, mappedRect.width), height: 20)
                context.fill(Path(roundedRect: badgeRect, cornerRadius: 6), with: .color(color(for: region.type)))
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
