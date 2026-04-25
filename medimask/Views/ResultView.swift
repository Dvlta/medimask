import SwiftUI
import UIKit

struct ResultView: View {
    let result: DetectionResult
    @State private var isShowingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Safe-to-Share Output")
                        .font(.title3.bold())

                    Image(uiImage: result.scrubbedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

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
                        ForEach(summaryLines, id: \.self) { line in
                            Text(line)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Time")
                            .font(.headline)
                        Group {
                            Text("Face detection: \(formattedMs(result.timings.faceDetectionMs))")
                            Text("OCR: \(formattedMs(result.timings.ocrMs))")
                            Text("PHI rules: \(formattedMs(result.timings.phiDetectionMs))")
                            Text("Redaction: \(formattedMs(result.timings.redactionMs))")
                            Text("Total: \(formattedMs(result.timings.totalMs))")
                                .fontWeight(.semibold)
                        }
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

    private func formattedMs(_ value: Double) -> String {
        "\(Int(value.rounded())) ms"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
