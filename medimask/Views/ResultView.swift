import SwiftUI
import UIKit

struct ResultView: View {
    let result: DetectionResult

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Scrubbed Output")
                        .font(.title3.bold())

                    Image(uiImage: result.scrubbedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Regions")
                            .font(.headline)
                        ForEach(result.regions) { region in
                            Text("\(region.label) • \(region.source)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Time")
                            .font(.headline)
                        Text("Total: \(Int(result.timings.totalMs)) ms")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Result")
        }
    }
}
