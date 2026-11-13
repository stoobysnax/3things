import Foundation

/// Saves the board as a small JSON file.
/// (When the iPhone app arrives, syncing will replace or sit beside this.)
public struct BoardFile {
    public let url: URL

    public init(url: URL = BoardFile.defaultURL) {
        self.url = url
    }

    /// ~/Library/Application Support/3 Today/board.json
    public static var defaultURL: URL { folder("3 Today").appendingPathComponent("board.json") }

    /// Where the app saved before it was renamed from 3 Things. Read once, if nothing newer exists.
    public static var legacyURL: URL { folder("3 Things").appendingPathComponent("board.json") }

    private static func folder(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(name, isDirectory: true)
    }

    public func load() -> Board {
        var data = try? Data(contentsOf: url)
        if data == nil, url == Self.defaultURL {
            data = try? Data(contentsOf: Self.legacyURL)
        }
        guard let data else { return Board() }
        do {
            return try Self.decoder.decode(Board.self, from: data)
        } catch {
            // Don't silently overwrite a file we can't read: keep a copy beside it.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
            try? FileManager.default.copyItem(at: url, to: backup)
            return Board()
        }
    }

    public func save(_ board: Board) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(board).write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
