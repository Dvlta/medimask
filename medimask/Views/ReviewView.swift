import SwiftUI
import UIKit

struct ReviewView: View {
    let image: UIImage
    let regions: [RedactionRegion]
    var title: String = "Review"
    @State private var selectedCategory: String? = nil
    @State private var selectedRegionID: UUID? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            GeometryReader { geometry in
                let focusRect = focusRectForCurrentSelection()
                let zoom = zoomTransform(for: focusRect, containerSize: geometry.size)

                ZStack {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        DetectionOverlayView(
                            imageSize: image.size,
                            containerSize: geometry.size,
                            regions: regions,
                            selectedCategory: selectedCategory,
                            selectedRegionID: selectedRegionID,
                            zoomScale: zoom.scale
                        ) { tappedCategory in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                selectedCategory = tappedCategory
                                selectedRegionID = nil
                            }
                        }
                    }
                    .scaleEffect(zoom.scale, anchor: .center)
                    .offset(x: zoom.offset.width, y: zoom.offset.height)
                    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: selectedCategory)
                    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: selectedRegionID)

                    if selectedCategory != nil || selectedRegionID != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                        selectedCategory = nil
                                        selectedRegionID = nil
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
            .frame(height: 430)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !regions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(
                            title: "ALL",
                            isSelected: selectedCategory == nil
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                selectedCategory = nil
                                selectedRegionID = nil
                            }
                        }

                        ForEach(categories, id: \.self) { category in
                            filterChip(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                    selectedCategory = category
                                    selectedRegionID = nil
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let selectedCategory, let bucket = groupedByCategory[selectedCategory], !bucket.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(bucket.enumerated()), id: \.element.id) { index, region in
                            filterChip(
                                title: subLabel(for: region, index: index + 1),
                                isSelected: selectedRegionID == region.id
                            ) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                                    selectedRegionID = (selectedRegionID == region.id) ? nil : region.id
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var categories: [String] {
        Array(groupedByCategory.keys).sorted()
    }

    private var groupedByCategory: [String: [RedactionRegion]] {
        Dictionary(grouping: regions) { category(for: $0.label) }
    }

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                .background(isSelected ? Color.red : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func subLabel(for region: RedactionRegion, index: Int) -> String {
        "\(index). \(region.label)"
    }

    private func focusRectForCurrentSelection() -> CGRect? {
        let selectedRegions: [RedactionRegion]
        if let selectedRegionID {
            selectedRegions = regions.filter { $0.id == selectedRegionID }
        } else if let selectedCategory {
            selectedRegions = regions.filter { category(for: $0.label) == selectedCategory }
        } else {
            selectedRegions = []
        }

        guard !selectedRegions.isEmpty else { return nil }
        return selectedRegions
            .map(\.rect)
            .reduce(CGRect.null) { partial, rect in
                partial.isNull ? rect : partial.union(rect)
            }
    }

    private func zoomTransform(for focusRect: CGRect?, containerSize: CGSize) -> (scale: CGFloat, offset: CGSize) {
        guard let focusRect,
              !focusRect.isNull,
              focusRect.width > 0,
              focusRect.height > 0 else {
            return (1.0, .zero)
        }

        let mapped = CoordinateMapper.mapImageRect(
            focusRect,
            imageSize: image.size,
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
