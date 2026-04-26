import PhotosUI
import SwiftUI
import UIKit

private enum HomeProcessingState {
    case idle
    case photoSelected(UIImage)
    case processing(UIImage)
}

struct HomeView: View {
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var detectionResult: DetectionResult?
    @State private var isShowingResult = false
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var appearAnimation = false
    @State private var breathe = false
    @State private var scanLineOffset: CGFloat = 0
    @State private var buttonPressed = false
    @State private var snowPhase: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var frostBreath = false

    private let pipeline = ImageProcessingPipeline()

    private let iceTeal = Color(red: 0.31, green: 0.69, blue: 0.72)
    private let iceLight = Color(red: 0.55, green: 0.82, blue: 0.85)
    private let iceDark = Color(red: 0.05, green: 0.12, blue: 0.15)
    private let iceMid = Color(red: 0.08, green: 0.18, blue: 0.22)
    private let frostWhite = Color(red: 0.85, green: 0.95, blue: 0.97)

    private var processingState: HomeProcessingState {
        if isScanning, let selectedImage {
            return .processing(selectedImage)
        }
        if let selectedImage {
            return .photoSelected(selectedImage)
        }
        return .idle
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [iceDark, iceMid, iceDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            snowfall
            frostMist

            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    headerSection
                    contentArea
                    actionButton
                    tagline
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
        }
        .fullScreenCover(isPresented: $isShowingResult) {
            if let detectionResult {
                ResultView(result: detectionResult)
            }
        }
        .alert("Scan Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onAppear(perform: startAmbientAnimation)
    }

    private var snowfall: some View {
        GeometryReader { geo in
            ForEach(0..<15, id: \.self) { i in
                let seed = Double(i) * 1.618
                let x = seed.truncatingRemainder(dividingBy: 1.0)
                let speed = 0.25 + Double(i % 4) * 0.12
                let size = CGFloat(1 + i % 3)
                Circle()
                    .fill(frostWhite.opacity(speed * 0.4))
                    .frame(width: size, height: size)
                    .position(
                        x: geo.size.width * CGFloat(x) + sin(Double(snowPhase) * .pi * 2 + seed * 3) * 12,
                        y: geo.size.height * CGFloat(
                            (Double(snowPhase) * speed + seed).truncatingRemainder(dividingBy: 1.0)
                        )
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var frostMist: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [iceTeal.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 80, y: -60)
                .blur(radius: 60)
                .opacity(frostBreath ? 0.8 : 0.3)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [iceLight.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: -60, y: 200)
                .blur(radius: 50)
                .opacity(frostBreath ? 0.6 : 0.2)
        }
        .allowsHitTesting(false)
    }

    private var headerSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                iceTeal.opacity(0.3),
                                iceLight.opacity(0.15),
                                frostWhite.opacity(0.25),
                                iceTeal.opacity(0.05),
                                iceTeal.opacity(0.3)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(ringRotation))

                Circle()
                    .fill(iceTeal.opacity(breathe ? 0.12 : 0.04))
                    .frame(width: 68, height: 68)
                    .blur(radius: 8)

                Image(systemName: "eye.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [frostWhite, iceTeal],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("SCRUBS")
                    .font(.system(size: 30, weight: .heavy).width(.compressed))
                    .scaleEffect(x: 0.75, y: 1.4)
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [frostWhite, iceTeal, iceLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("S U B · Z E R O")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(iceTeal.opacity(0.5))
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : -30)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch processingState {
        case .idle:
            uploadArea(preview: nil)
        case .photoSelected(let image):
            uploadArea(preview: image)
        case .processing(let image):
            processingArea(image)
        }
    }

    private func uploadArea(preview: UIImage?) -> some View {
        VStack(spacing: 24) {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [frostWhite.opacity(0.3), iceTeal.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: iceTeal.opacity(0.15), radius: 30, y: 10)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("change photo")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(iceLight.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(frostWhite.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(frostWhite.opacity(0.08), lineWidth: 1))
                }
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .stroke(iceTeal.opacity(breathe ? 0.2 : 0.06), lineWidth: 1)
                                .frame(width: 120, height: 120)
                                .scaleEffect(breathe ? 1.1 : 0.95)

                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [frostWhite.opacity(0.25), iceTeal.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 96, height: 96)

                            Circle()
                                .fill(iceTeal.opacity(breathe ? 0.1 : 0.04))
                                .frame(width: 72, height: 72)
                                .blur(radius: 10)

                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 34, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [frostWhite, iceTeal],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }

                        VStack(spacing: 8) {
                            Text("Upload Image")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(frostWhite.opacity(0.9))

                            Text("tap to select from your library")
                                .font(.system(size: 14))
                                .foregroundColor(frostWhite.opacity(0.3))
                        }

                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(iceTeal.opacity(0.4))
                                    .frame(width: 2, height: breathe ? 8 : 4)
                                    .animation(
                                        .easeInOut(duration: 1.2)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.2),
                                        value: breathe
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                await loadPhoto(from: newItem)
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedImage)
    }

    private func processingArea(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .blur(radius: 6)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(iceDark.opacity(0.4)))
                .overlay(
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, frostWhite.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 50)
                            .offset(y: scanLineOffset * geo.size.height)
                            .blur(radius: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(iceTeal.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: iceTeal.opacity(0.1), radius: 25, y: 8)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(frostWhite.opacity(0.06), lineWidth: 2.5)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [frostWhite, iceTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(Double(scanLineOffset) * 1080))
                }

                Text("Freezing data")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(frostWhite.opacity(0.9))

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(iceTeal)
                            .frame(width: 5, height: 5)
                            .opacity(Double(scanLineOffset) > Double(i) * 0.3 ? 0.8 : 0.2)
                    }
                }
            }
        }
        .onAppear {
            scanLineOffset = 0
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                scanLineOffset = 1
            }
        }
    }

    private var actionButton: some View {
        Button {
            buttonPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                buttonPressed = false
            }
            Task {
                await scanSelectedImage()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                Text(isScanning ? "Freezing..." : "Blur Photo")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(buttonEnabled ? iceDark : frostWhite.opacity(0.2))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(actionButtonBackground)
            .clipShape(Capsule())
        }
        .disabled(!buttonEnabled || isScanning)
        .scaleEffect(buttonPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: buttonPressed)
        .shadow(color: buttonEnabled ? iceTeal.opacity(0.3) : .clear, radius: 20, y: 8)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    @ViewBuilder
    private var actionButtonBackground: some View {
        if buttonEnabled {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [iceTeal, iceLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [frostWhite.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
        } else {
            Capsule()
                .fill(frostWhite.opacity(0.04))
                .overlay(Capsule().strokeBorder(frostWhite.opacity(0.06), lineWidth: 1))
        }
    }

    private var buttonEnabled: Bool {
        selectedImage != nil && !isScanning
    }

    private var tagline: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(iceTeal.opacity(0.3))
                .frame(width: 12, height: 1)
            Text("freeze the noise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(frostWhite.opacity(0.2))
            RoundedRectangle(cornerRadius: 1)
                .fill(iceTeal.opacity(0.3))
                .frame(width: 12, height: 1)
        }
        .opacity(appearAnimation ? 1 : 0)
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

    private func startAmbientAnimation() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
            appearAnimation = true
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathe = true
        }
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            snowPhase = 1
        }
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            frostBreath = true
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            selectedImage = image
            detectionResult = nil
            isShowingResult = false
        }
    }

    @MainActor
    private func scanSelectedImage() async {
        guard let selectedImage, !isScanning else { return }

        isScanning = true
        detectionResult = nil

        do {
            let result = try await pipeline.process(image: selectedImage)
            detectionResult = result
            isShowingResult = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }
}
