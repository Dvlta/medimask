import SwiftUI
import UIKit

struct ReviewView: View {
    let image: UIImage
    let regions: [RedactionRegion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review")
                .font(.headline)
            Text(regions.isEmpty ? "Scan to detect sensitive regions." : "\(regions.count) region(s) highlighted")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

            if !regions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(uniqueLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var uniqueLabels: [String] {
        Array(Set(regions.map(\.label))).sorted()
    }
}
