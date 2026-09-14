import Foundation

public struct TabSessionLog: Sendable {
    public static let defaultURL = URL(fileURLWithPath: NSHomeDirectory())
        .appending(path: ".claude/supacode-tab-sessions.log")

    static let tailWindow: UInt64 = 8 * 1024 * 1024

    private struct Fingerprint: Equatable, Sendable {
        let modified: Date
        let size: Int
    }

    private let url: URL
    private var fingerprint: Fingerprint?
    private var sessions: [String: String] = [:]

    public init(url: URL = TabSessionLog.defaultURL) {
        self.url = url
    }

    public mutating func sessionId(forTab tabId: String) -> String? {
        refresh()
        return sessions[tabId.uppercased()]
    }

    private mutating func refresh() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? Int
        else { return }

        let current = Fingerprint(modified: modified, size: size)
        guard current != fingerprint else { return }

        fingerprint = current
        sessions = Self.parse(tailOf: url)
    }

    private static func parse(tailOf url: URL) -> [String: String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [:] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [:] }

        let offset = size > tailWindow ? size - tailWindow : 0
        guard (try? handle.seek(toOffset: offset)) != nil, let tail = try? handle.readToEnd() else { return [:] }

        var lines = String(decoding: tail, as: UTF8.self).split(separator: "\n")
        if offset > 0, !lines.isEmpty { lines.removeFirst() }

        var resolved: [String: String] = [:]
        for line in lines {
            let fields = line.split(separator: " ")
            guard fields.count >= 2 else { continue }
            resolved[fields[0].uppercased()] = String(fields[1])
        }
        return resolved
    }
}
