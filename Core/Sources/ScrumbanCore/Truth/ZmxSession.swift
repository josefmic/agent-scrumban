import Foundation

public struct ZmxSession: Equatable, Sendable {
    public let name: String
    public let pid: Int32
    public let clients: Int
    public let startDirectory: String
    public let created: Date?
    public let focused: Bool
}

public enum ZmxListParser {
    public static func parse(_ output: String) -> [ZmxSession] {
        output.split(separator: "\n").compactMap(parseLine)
    }

    private static func parseLine(_ line: Substring) -> ZmxSession? {
        let focused = line.hasPrefix("→")
        let body = line.drop { $0 == "→" || $0 == " " }

        var fields: [String: String] = [:]
        for field in body.split(separator: "\t") {
            guard let separator = field.firstIndex(of: "=") else { continue }
            fields[String(field[..<separator])] = String(field[field.index(after: separator)...])
        }

        guard let name = fields["name"],
              let pid = fields["pid"].flatMap(Int32.init),
              let startDirectory = fields["start_dir"]
        else { return nil }

        return ZmxSession(
            name: name,
            pid: pid,
            clients: fields["clients"].flatMap(Int.init) ?? 0,
            startDirectory: startDirectory,
            created: fields["created"].flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:)),
            focused: focused
        )
    }
}
