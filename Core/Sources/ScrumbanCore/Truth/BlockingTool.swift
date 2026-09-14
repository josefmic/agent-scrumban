public enum BlockingTool: String, Equatable, Sendable, CaseIterable {
    case askUserQuestion = "AskUserQuestion"
    case exitPlanMode = "ExitPlanMode"

    static func blocksOnUser(_ name: String) -> Bool { BlockingTool(rawValue: name) != nil }
}
