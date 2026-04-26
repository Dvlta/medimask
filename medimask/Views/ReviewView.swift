import SwiftUI
import UIKit

struct ReviewView: View {
    let image: UIImage
    let regions: [RedactionRegion]
    var title: String = "Review"
    @State private var selectedCategory: String? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    DetectionOverlayView(
                        imageSize: image.size,
                        containerSize: geometry.size,
                        regions: regions,
                        selectedCategory: selectedCategory
                    )
                }
            }
            .frame(height: 420)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !regions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("ALL") {
                            selectedCategory = nil
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedCategory == nil ? Color.red : Color(.tertiarySystemBackground))
                        .foregroundStyle(selectedCategory == nil ? .white : .primary)
                        .clipShape(Capsule())

                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = (selectedCategory == category) ? nil : category
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category ? Color.red : Color(.tertiarySystemBackground))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            if let selectedCategory,
               let sublabels = groupedLabels[selectedCategory],
               !sublabels.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(selectedCategory) details")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sublabels, id: \.self) { label in
                                Text(label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.10))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var categories: [String] {
        Array(Set(regions.map { category(for: $0.label) })).sorted()
    }

    private var groupedLabels: [String: [String]] {
        Dictionary(grouping: regions, by: { category(for: $0.label) }).mapValues { group in
            Array(Set(group.map(\.label))).sorted()
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
