import SwiftUI
import UIKit

struct ReviewView: View {
    let image: UIImage
    let regions: [RedactionRegion]
    var title: String = "Review"

    @State private var selectedCategory: String?
    @State private var selectedRegionID: UUID?

    private let iceTeal = Color(red: 0.31, green: 0.69, blue: 0.72)
    private let iceLight = Color(red: 0.55, green: 0.82, blue: 0.85)
    private let iceDark = Color(red: 0.05, green: 0.12, blue: 0.15)
    private let frostWhite = Color(red: 0.85, green: 0.95, blue: 0.97)
    private let iceCard = Color(red: 0.07, green: 0.16, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .heavy).width(.condensed))
                    .foregroundColor(frostWhite)
                Spacer()
                if !regions.isEmpty {
                    Text("Tap to zoom")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(frostWhite.opacity(0.32))
                }
            }

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
                                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(iceDark)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(iceLight))
                                }
                            }
                            Spacer()
                        }
                        .padding(10)
                    }
                }
            }
            .frame(height: 340)
            .background(iceCard.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(iceTeal.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            if !regions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "ALL", isSelected: selectedCategory == nil) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                selectedCategory = nil
                                selectedRegionID = nil
                            }
                        }

                        ForEach(categories, id: \.self) { category in
                            filterChip(title: category, isSelected: selectedCategory == category) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                    selectedCategory = category
                                    selectedRegionID = nil
                                }
                            }
                        }
                    }
                }
            }

            if let selectedCategory, let bucket = groupedByCategory[selectedCategory], !bucket.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(bucket.enumerated()), id: \.element.id) { index, region in
                            filterChip(
                                title: "\(index + 1). \(region.label)",
                                isSelected: selectedRegionID == region.id,
                                multiline: true
                            ) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.90)) {
                                    selectedRegionID = selectedRegionID == region.id ? nil : region.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var categories: [String] {
        Array(groupedByCategory.keys).sorted()
    }

    private var groupedByCategory: [String: [RedactionRegion]] {
        Dictionary(grouping: regions) { displayLabel(for: $0.label) }
    }

    private func filterChip(
        title: String,
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
                                .strokeBorder(isSelected ? iceLight.opacity(0.0) : iceTeal.opacity(0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func focusRectForCurrentSelection() -> CGRect? {
        let selectedRegions: [RedactionRegion]
        if let selectedRegionID {
            selectedRegions = regions.filter { $0.id == selectedRegionID }
        } else if let selectedCategory {
            selectedRegions = regions.filter { displayLabel(for: $0.label) == selectedCategory }
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
        return (scale, CGSize(width: (center.x - target.x) * scale, height: (center.y - target.y) * scale))
    }

    private func displayLabel(for label: String) -> String {
        label.isEmpty ? "Sensitive Region" : label.displayTitle
    }
}

private extension String {
    var displayTitle: String {
        replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}
