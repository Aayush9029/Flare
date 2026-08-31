import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct ImageStore: Sendable {
    /// Writes PNG data and returns the file name to store on the message.
    public var save: @Sendable (Data) throws -> String
    public var url: @Sendable (String) -> URL?
}

extension ImageStore: DependencyKey {
    public static let directory = URL.applicationSupportDirectory
        .appending(path: "Flare", directoryHint: .isDirectory)
        .appending(path: "images", directoryHint: .isDirectory)

    public static let liveValue = Self(
        save: { data in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "\(UUID().uuidString).png"
            try data.write(to: directory.appending(path: name), options: [.atomic])
            return name
        },
        url: { name in
            guard !name.isEmpty else { return nil }
            let url = directory.appending(path: name)
            return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
    )
}

extension ImageStore: TestDependencyKey {
    public static let testValue = Self(save: { _ in "test.png" }, url: { _ in nil })
}

public extension DependencyValues {
    var imageStore: ImageStore {
        get { self[ImageStore.self] }
        set { self[ImageStore.self] = newValue }
    }
}
