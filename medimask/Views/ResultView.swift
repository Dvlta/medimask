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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Regions")
                            .font(.headline)
                        if result.regions.isEmpty {
                            Text("No sensitive regions found.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(result.regions) { region in
                                Text("\(region.label) • \(region.source)")
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

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label("Share Scrubbed Image", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
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
}
