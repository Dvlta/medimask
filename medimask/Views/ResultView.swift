import SwiftUI
import UIKit

struct ResultView: View {
    let result: DetectionResult
    @State private var selectedTab: Tab = .scrubbed
    @State private var isShowingShareSheet = false

    private enum Tab: String, CaseIterable, Identifiable {
        case original = "Original"
        case scrubbed = "Scrubbed"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Safe-to-share copy created")
                    Text("Safe-to-Share Output")
                        .font(.title3.bold())

                    Picker("Preview", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Label("Processed on-device. No upload required.", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)

                    HStack(spacing: 12) {
                        Button {
                            isShowingShareSheet = true
                        } label: {
                            Label("Share Scrubbed Image", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            UIImageWriteToSavedPhotosAlbum(result.scrubbedImage, nil, nil, nil)
                        } label: {
                            Label("Save Copy", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Summary")
                            .font(.headline)
                        if result.regions.isEmpty {
                            Text("No sensitive regions found.")
                        } else {
                            ForEach(summaryLines, id: \.self) { line in
                                Text(line)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Time")
                            .font(.headline)
                        Text("Face detection: \(timingString(result.timings.faceDetectionMs))")
                            .foregroundStyle(.secondary)
                        Text("OCR: \(timingString(result.timings.ocrMs))")
                            .foregroundStyle(.secondary)
                        Text("PHI rules: \(timingString(result.timings.phiDetectionMs))")
                            .foregroundStyle(.secondary)
                        Text("Redaction: \(timingString(result.timings.redactionMs))")
                            .foregroundStyle(.secondary)
                        Text("Total: \(timingString(result.timings.totalMs))")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Result")
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [result.scrubbedImage])
            }
        }
    }

    private var previewImage: UIImage {
        switch selectedTab {
        case .original:
            return result.originalImage
        case .scrubbed:
            return result.scrubbedImage
        }
    }

    private func timingString(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }

    private var summaryLines: [String] {
        let grouped = Dictionary(grouping: result.regions, by: \.label)
        let sortedLabels = grouped.keys.sorted()
        if sortedLabels.isEmpty {
            return ["No detections found."]
        }
        var lines = sortedLabels.map { label in
            "\(label): \(grouped[label]?.count ?? 0)"
        }
        lines.append("Total regions: \(result.regions.count)")
        return lines
    }
}
