import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    @State private var selectedImage: UIImage?
    @State private var detectionResult: DetectionResult?
    @State private var isShowingResult = false
    @State private var isScanning = false
    @State private var errorMessage: String?

    private let pipeline = ImageProcessingPipeline()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    PhotoPickerView(selectedImage: $selectedImage)
                    scanSection
                    summarySection
                }
                .padding(20)
            }
            .navigationTitle("MediMask")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $isShowingResult) {
                if let result = detectionResult {
                    ResultView(result: result)
                }
            }
            .alert("Scan Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan healthcare photos locally before you share them.")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            Text("Faces, patient identifiers, and obvious PHI are detected on-device and redacted into a safe copy.")
                .foregroundStyle(.secondary)
            Label("Designed to work offline", systemImage: "airplane")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedImage {
                ReviewView(
                    image: selectedImage,
                    regions: detectionResult?.regions ?? []
                )
            } else {
                ContentUnavailableView(
                    "No Photo Selected",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Import a healthcare-related photo to review and scrub locally.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Button {
                Task {
                    await scanSelectedImage()
                }
            } label: {
                HStack {
                    Image(systemName: "viewfinder")
                    Text(isScanning ? "Scanning Locally..." : "Scan Photo")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || isScanning)

            if isScanning {
                ProcessingStatusView(message: "Running face detection, OCR, and PHI rules on-device...")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var summarySection: some View {
        if let detectionResult {
            VStack(alignment: .leading, spacing: 12) {
                Text("Latest Scan")
                    .font(.headline)
                ForEach(detectionSummaryLines(for: detectionResult), id: \.self) { line in
                    Text(line)
                        .foregroundStyle(.secondary)
                }
                Button("Review Scrubbed Result") {
                    isShowingResult = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func detectionSummaryLines(for result: DetectionResult) -> [String] {
        let grouped = Dictionary(grouping: result.regions, by: \.label)
        let summary = grouped
            .keys
            .sorted()
            .map { label in
                "\(label): \(grouped[label]?.count ?? 0)"
            }
        return summary + ["Total: \(result.regions.count) regions"]
    }

    @MainActor
    private func scanSelectedImage() async {
        guard let selectedImage else { return }

        isScanning = true
        detectionResult = nil

        do {
            detectionResult = try await pipeline.process(image: selectedImage)
            isShowingResult = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }
}
