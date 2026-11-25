import Foundation

/// A JSON list kept on the device (favorites, picks). A missing, empty or unreadable file reads as
/// empty; unreadable bytes (corrupt, or a future schema) are copied to `<name>.corrupt.json`
/// before the first write replaces them.
struct LocalJSONFile<Element: Codable & Sendable>: Sendable {
    private let file: URL
    /// Bytes of a non-empty file that could not be decoded, kept aside before the first write.
    private var unreadable: Data?

    init(_ file: URL) { self.file = file }

    /// Reads the file once, at start.
    mutating func read() -> [Element] {
        let saved = (try? Data(contentsOf: file)) ?? Data()
        let decoded = try? Self.decoder.decode([Element].self, from: saved)
        unreadable = decoded == nil && !saved.isEmpty ? saved : nil
        return decoded ?? []
    }

    mutating func write(_ elements: [Element], now: Date) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try keepUnreadableAside(now: now)
        try Self.encoder.encode(elements).write(to: file, options: .atomic)
    }

    /// Never overwrites an earlier copy: a second one gets a timestamped name.
    private mutating func keepUnreadableAside(now: Date) throws {
        guard let unreadable else { return }
        let directory = file.deletingLastPathComponent()
        let name = file.deletingPathExtension().lastPathComponent
        var copy = directory.appending(path: "\(name).corrupt.json")
        if FileManager.default.fileExists(atPath: copy.path) {
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyyMMdd-HHmmss"
            copy = directory.appending(path: "\(name).corrupt-\(format.string(from: now)).json")
        }
        try unreadable.write(to: copy, options: .withoutOverwriting)
        self.unreadable = nil
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
