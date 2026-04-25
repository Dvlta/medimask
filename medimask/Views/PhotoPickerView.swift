import PhotosUI
import SwiftUI
import UIKit

struct PhotoPickerView: View {
    @Binding var selectedImage: UIImage?
    var onError: (String) -> Void = { _ in }

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Input")
                .font(.headline)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Import From Photo Library", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(role: .destructive) {
                    self.selectedImage = nil
                } label: {
                    Label("Remove Selected Photo", systemImage: "trash")
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
        .task(id: selectedItem) {
            guard let selectedItem else { return }

            do {
                if let data = try await selectedItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                } else {
                    onError("The selected image could not be loaded. Please choose another photo.")
                }
            } catch {
                Logger.app.error("Failed to load selected photo: \(error.localizedDescription)")
                onError("Could not import the selected photo. Please try again.")
            }
        }
    }
}
