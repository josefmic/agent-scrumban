import Foundation

public enum AgentActivity: Equatable, Sendable {
    case working
    case awaitingInput
    case idle
}

public enum TranscriptLookup: Equatable, Sendable {
    case session(String)
    case soleSessionInWorktree
    case unresolved
}

enum TranscriptEnd: Equatable, Sendable {
    case finishedTurn
    case blockedOnUser
    case inProgress
}

private struct TranscriptEntry: Decodable {
    struct ContentBlock: Decodable {
        let type: String?
        let name: String?
        let text: String?
    }

    struct Message: Decodable {
        let stopReason: String?
        let tools: [String]

        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            stopReason = try? container.decode(String.self, forKey: .stopReason)
            let blocks = (try? container.decode([ContentBlock].self, forKey: .content)) ?? []
            tools = blocks.compactMap { $0.type == "tool_use" ? $0.name : nil }
        }
    }

    let type: String
    let subtype: String?
    let message: Message?

    enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        subtype = try? container.decode(String.self, forKey: .subtype)
        message = try? container.decode(Message.self, forKey: .message)
    }
}

public struct TranscriptStore: Sendable {
    public static let defaultRoot = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".claude/projects")

    static let initialWindow: UInt64 = 64 * 1024
    static let maximumWindow: UInt64 = 8 * 1024 * 1024

    private struct Fingerprint: Equatable, Sendable {
        let url: URL
        let modified: Date
        let size: Int
    }

    private struct Reading: Sendable {
        let fingerprint: Fingerprint
        let end: TranscriptEnd
    }

    private let root: URL
    private var readings: [String: Reading] = [:]

    public init(root: URL = TranscriptStore.defaultRoot) {
        self.root = root
    }

    public static func directoryName(forWorktreePath path: String) -> String {
        String(path.map { $0 == "/" || $0 == "." ? "-" : $0 })
    }

    public mutating func activity(
        forWorktreePath path: String,
        lookup: TranscriptLookup,
        working: Bool = false
    ) -> AgentActivity {
        guard let transcript = transcript(forWorktreePath: path, lookup: lookup) else {
            return working ? .working : .idle
        }

        let end: TranscriptEnd
        if let known = readings[transcript.url.path], known.fingerprint == transcript {
            end = known.end
        } else {
            end = Self.read(at: transcript.url) ?? .inProgress
            readings[transcript.url.path] = Reading(fingerprint: transcript, end: end)
        }

        if end == .blockedOnUser { return .awaitingInput }
        if working { return .working }

        return end == .finishedTurn ? .awaitingInput : .idle
    }

    private func transcript(forWorktreePath path: String, lookup: TranscriptLookup) -> Fingerprint? {
        let directory = root.appending(path: Self.directoryName(forWorktreePath: path))

        switch lookup {
        case .session(let id): return fingerprint(of: directory.appending(path: "\(id).jsonl"))
        case .soleSessionInWorktree: return newestTranscript(in: directory)
        case .unresolved: return nil
        }
    }

    private func fingerprint(of url: URL) -> Fingerprint? {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: Set(keys)),
              let modified = values.contentModificationDate,
              let size = values.fileSize
        else { return nil }
        return Fingerprint(url: url, modified: modified, size: size)
    }

    private func newestTranscript(in directory: URL) -> Fingerprint? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return nil }

        return entries
            .filter { $0.pathExtension == "jsonl" }
            .compactMap(fingerprint(of:))
            .max { $0.modified < $1.modified }
    }

    private static func read(at url: URL) -> TranscriptEnd? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }

        var window = initialWindow
        while true {
            let offset = size > window ? size - window : 0
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let tail = try? handle.readToEnd()
            else { return nil }

            if let end = end(inTail: tail, reachesFileStart: offset == 0) { return end }
            if offset == 0 || window >= maximumWindow { return nil }
            window *= 8
        }
    }

    private static func end(inTail tail: Data, reachesFileStart: Bool) -> TranscriptEnd? {
        var lines = tail.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        if !reachesFileStart, !lines.isEmpty { lines.removeFirst() }

        let decoder = JSONDecoder()
        for line in lines.reversed() {
            guard let entry = try? decoder.decode(TranscriptEntry.self, from: line) else { continue }

            switch entry.type {
            case "system" where entry.subtype == "stop_hook_summary":
                return .finishedTurn
            case "assistant":
                switch entry.message?.stopReason {
                case "end_turn": return .finishedTurn
                case "tool_use":
                    let blocked = entry.message?.tools.contains(where: BlockingTool.blocksOnUser) ?? false
                    return blocked ? .blockedOnUser : .inProgress
                default: return .inProgress
                }
            case "user":
                return .inProgress
            default: continue
            }
        }

        return reachesFileStart ? .inProgress : nil
    }
}
