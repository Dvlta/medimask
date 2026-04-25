import SwiftUI
import UIKit

struct ReviewView: View {
    let image: UIImage
    let regions: [RedactionRegion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    DetectionOverlayView(
                        imageSize: image.size,
                        containerSize: geometry.size,
                        regions: regions
                    )
                }
            }
            .frame(height: 320)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
