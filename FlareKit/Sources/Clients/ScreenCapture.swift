import Foundation

/// The system's interactive screenshot: the crosshair, a drag, and the PNG that
/// results. Escape gives nil.
public enum ScreenCapture {
    public static func interactive() async -> Data? {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "flare-capture-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-t", "png", file.path]
        do {
            try process.run()
        } catch {
            return nil
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        defer { try? FileManager.default.removeItem(at: file) }
        return try? Data(contentsOf: file)
    }
}
