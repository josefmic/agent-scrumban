import Foundation

public enum AgentEnvironment {
    static let tabVariable = "SUPACODE_TAB_ID="

    public static func tabs(ofProcesses pids: [Int32], runner: CommandRunner) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }

        let listing = try? runner.run("/bin/ps", [
            "-wwE", "-o", "pid=,command=", "-p", pids.map(String.init).joined(separator: ","),
        ])

        return listing.map(parse) ?? [:]
    }

    static func parse(_ listing: String) -> [Int32: String] {
        var tabs: [Int32: String] = [:]

        for line in listing.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let pid = fields.first.flatMap({ Int32($0) }),
                  let tab = fields.first(where: { $0.hasPrefix(tabVariable) })?.dropFirst(tabVariable.count),
                  !tab.isEmpty
            else { continue }
            tabs[pid] = String(tab)
        }

        return tabs
    }
}
