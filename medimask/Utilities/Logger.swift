import OSLog

enum Logger {
    static let app = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "medimask", category: "app")
}
