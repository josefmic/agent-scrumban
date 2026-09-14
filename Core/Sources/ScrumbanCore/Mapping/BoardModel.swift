import Foundation

public struct Card: Equatable, Sendable, Identifiable {
    public let columnName: String
    public let issueKey: String?
    public let summary: String
    public let epic: JiraEpic?
    public let issueType: String
    public let priority: String
    public let storyPoints: Double?
    public let assignee: JiraUser?
    public let epicColor: String
    public let worktreePath: String?
    public let sessions: [AgentSession]
    public let branch: String?
    public let diffstat: DiffStat?

    public init(
        columnName: String,
        issueKey: String?,
        summary: String,
        epic: JiraEpic? = nil,
        issueType: String = "",
        priority: String = "",
        storyPoints: Double? = nil,
        assignee: JiraUser? = nil,
        epicColor: String = "",
        worktreePath: String?,
        sessions: [AgentSession] = [],
        branch: String?,
        diffstat: DiffStat?
    ) {
        self.columnName = columnName
        self.issueKey = issueKey
        self.summary = summary
        self.epic = epic
        self.issueType = issueType
        self.priority = priority
        self.storyPoints = storyPoints
        self.assignee = assignee
        self.epicColor = epicColor
        self.worktreePath = worktreePath
        self.sessions = sessions
        self.branch = branch
        self.diffstat = diffstat
    }

    public var agentSessions: [AgentSession] { sessions.filter { $0.harness != nil } }

    public var id: String { "\(columnName)/\(issueKey ?? worktreePath ?? summary)" }
}

public struct BoardColumnModel: Equatable, Sendable, Identifiable {
    public let name: String
    public let cards: [Card]
    public let total: Int

    public init(name: String, cards: [Card], total: Int? = nil) {
        self.name = name
        self.cards = cards
        self.total = total ?? cards.count
    }

    public var id: String { name }
}

public enum BoardModel {
    public static func build(
        columns: [JiraColumn],
        issues: [JiraIssue],
        allIssues: [JiraIssue] = [],
        worktrees: [WorktreeState],
        branches: [String: String],
        diffstats: [String: DiffStat] = [:]
    ) -> [BoardColumnModel] {
        var worktreeByKey: [String: WorktreeState] = [:]

        for worktree in worktrees {
            guard let branch = branches[worktree.path],
                  let key = IssueKey.extract(fromBranch: branch),
                  worktreeByKey[key] == nil
            else { continue }
            worktreeByKey[key] = worktree
        }

        return columns.map { column in
            let statuses = Set(column.statusIds)
            let cards = issues.filter { statuses.contains($0.statusId) }.map { issue -> Card in
                let worktree = worktreeByKey[issue.key]
                return Card(
                    columnName: column.name,
                    issueKey: issue.key,
                    summary: issue.summary,
                    epic: issue.epic,
                    issueType: issue.issueType,
                    priority: issue.priority,
                    storyPoints: issue.storyPoints,
                    assignee: issue.assignee,
                    epicColor: issue.epicColor,
                    worktreePath: worktree?.path,
                    sessions: worktree?.sessions ?? [],
                    branch: worktree.flatMap { branches[$0.path] },
                    diffstat: worktree.flatMap { diffstats[$0.path] }
                )
            }

            return BoardColumnModel(
                name: column.name,
                cards: cards,
                total: allIssues.isEmpty ? cards.count : allIssues.count { statuses.contains($0.statusId) }
            )
        }
    }
}
