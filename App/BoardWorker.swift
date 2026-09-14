import Foundation
import ScrumbanCore

struct BoardSnapshot: Sendable {
    let columns: [BoardColumnModel]
    let worktrees: Int
}

actor BoardWorker {
    static let gitInterval: TimeInterval = 30

    private struct GitFacts {
        let branch: String?
        let diffstat: DiffStat
    }

    private var truth: TruthService
    private let git: GitReader
    private let supacode: SupacodeDriver
    private let gitInterval: TimeInterval

    private var cache: [String: GitFacts] = [:]
    private var lastGitPass: Date?
    private var cachedBaseBranch: String?

    init(runner: CommandRunner, gitInterval: TimeInterval = BoardWorker.gitInterval) {
        truth = TruthService(runner: runner)
        git = GitReader(runner: runner)
        supacode = SupacodeDriver(runner: runner)
        self.gitInterval = gitInterval
    }

    func focusedWorktree() throws -> String? {
        SupacodeCommand.focused(in: try supacode.run(SupacodeCommand.focusedWorktree()))
    }

    func board(
        columns: [JiraColumn],
        issues: [JiraIssue],
        allIssues: [JiraIssue],
        baseBranch: String,
        now: Date = Date()
    ) throws -> BoardSnapshot {
        let worktrees = try truth.snapshot()

        if cachedBaseBranch != baseBranch {
            cachedBaseBranch = baseBranch
            cache.removeAll()
            lastGitPass = nil
        }

        let live = Set(worktrees.map(\.path))
        cache = cache.filter { live.contains($0.key) }

        let due = lastGitPass.map { now.timeIntervalSince($0) >= gitInterval } ?? true
        for worktree in worktrees where due || cache[worktree.path] == nil {
            cache[worktree.path] = GitFacts(
                branch: git.branch(at: worktree.path),
                diffstat: git.diffstat(at: worktree.path, baseBranch: baseBranch)
            )
        }
        if due { lastGitPass = now }

        return BoardSnapshot(
            columns: BoardModel.build(
                columns: columns,
                issues: issues,
                allIssues: allIssues,
                worktrees: worktrees,
                branches: cache.compactMapValues(\.branch),
                diffstats: cache.mapValues(\.diffstat)
            ),
            worktrees: worktrees.count
        )
    }
}
