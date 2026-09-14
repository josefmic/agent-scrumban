import Foundation

public enum AgentKind: String, Equatable, Sendable, CaseIterable {
    case claude
    case codex
    case copilot
    case aider
    case opencode
    case gemini
}

public enum AgentDetector {
    public static func kind(of process: RunningProcess) -> AgentKind? {
        guard let executable = process.command.split(separator: " ").first else { return nil }
        return AgentKind(rawValue: String(executable.split(separator: "/").last ?? executable))
    }

    public static func isAgent(_ process: RunningProcess) -> Bool {
        kind(of: process) != nil
    }
}
