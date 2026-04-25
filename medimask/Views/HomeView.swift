import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    @State private var selectedImage: UIImage?
    @State private var detectionResult: DetectionResult?
    @State private var isShowingResult = false
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var hasCompletedScan = false

    private let pipeline = ImageProcessingPipeline()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    PhotoPickerView(selectedImage: $selectedImage) { message in
                        errorMessage = message
                    }
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
            .onChange(of: selectedImage) { _, _ in
                detectionResult = nil
                hasCompletedScan = false
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
            Label("Processed on-device. No upload required.", systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
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
                    Text(isScanning ? "Scanning locally..." : "Scan Photo")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || isScanning)

            if isScanning {
                ProcessingStatusView(message: "Running face detection, OCR, and PHI rules on-device...")
            }

            if hasCompletedScan, detectionResult != nil {
                Button {
                    isShowingResult = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Scrub Photo")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
                Button("Open Result") {
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
        let faceCount = result.regions.filter { $0.type == .face }.count
        let textCount = result.regions.filter { $0.type == .phiText }.count
        let objectCount = result.regions.filter { $0.type == .object }.count

        let grouped = Dictionary(grouping: result.regions, by: \.label)
        let summary = grouped
            .keys
            .sorted()
            .map { label in
                "\(label): \(grouped[label]?.count ?? 0)"
            }
        return [
            "Detected:",
            "- Faces: \(faceCount)",
            "- PHI text: \(textCount)",
            "- Objects: \(objectCount)"
        ] + summary + ["Total: \(result.regions.count) regions"]
    }

    @MainActor
    private func scanSelectedImage() async {
        guard let selectedImage else { return }

        isScanning = true
        detectionResult = nil
        hasCompletedScan = false

        do {
            detectionResult = try await pipeline.process(image: selectedImage)
            hasCompletedScan = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }
}
