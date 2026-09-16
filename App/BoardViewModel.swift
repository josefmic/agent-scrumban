import Foundation
import ScrumbanCore

@MainActor
final class BoardViewModel: ObservableObject {
    @Published private(set) var columns: [BoardColumnModel] = []
    @Published private(set) var focusedWorktree: String?
    @Published private(set) var worktreeCount = 0
    @Published private(set) var loaded = false
    @Published private(set) var hasToken = false
    @Published var errorMessage: String?
    var baseBranch = GitReader.defaultBaseBranch

    private let worker: BoardWorker
    private nonisolated let driver: SupacodeDriver

    private var jiraColumns: [JiraColumn] = []
    private var issues: [JiraIssue] = []
    private var unfilteredIssues: [JiraIssue] = []
    private var timer: Timer?
    private var refreshing = false

    private var jira: JiraClient?
    private var boardId: Int?
    private var sprintId: Int?
    private var activeJql = ""

    private let activator: AppActivating
    private let opener: URLOpening
    private nonisolated let runner: CommandRunner

    init(
        activator: AppActivating = WorkspaceActivator(),
        opener: URLOpening = WorkspaceOpener(),
        runner: CommandRunner = SystemCommandRunner()
    ) {
        self.activator = activator
        self.opener = opener
        self.runner = runner
        worker = BoardWorker(runner: runner)
        driver = SupacodeDriver(runner: runner)
    }

    func start() {
        Task { await tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() async {
        guard !refreshing else { return }
        refreshing = true
        await refreshTruth()
        refreshing = false
    }

    func refreshTruth() async {
        do {
            let snapshot = try await worker.board(
                columns: jiraColumns,
                issues: issues,
                allIssues: unfilteredIssues,
                baseBranch: baseBranch
            )
            columns = snapshot.columns
            worktreeCount = snapshot.worktrees
            focusedWorktree = try await worker.focusedWorktree()
        } catch {
            report(error)
        }
    }

    func isFocused(_ card: Card) -> Bool {
        guard let path = card.worktreePath, let focusedWorktree else { return false }
        return SupacodeCommand.identifier(forPath: path) == focusedWorktree
    }

    func focus(_ card: Card) async {
        guard let path = card.worktreePath else { return }
        await focusWorktree(path)
    }

    private func focusWorktree(_ path: String) async {
        let previous = focusedWorktree
        let worktreeId = SupacodeCommand.identifier(forPath: path)
        focusedWorktree = worktreeId

        do {
            try await supacode(SupacodeCommand.focus(worktreeId: worktreeId))
            _ = activator.activate(bundleIdentifier: Supacode.bundleIdentifier)
        } catch {
            focusedWorktree = previous
            report(error)
        }
    }

    func focus(_ session: AgentSession, in worktreePath: String) async {
        guard let surface = SupacodeCommand.surfaceIdentifier(forSession: session.name) else { return }
        guard let tab = session.tab else { return await focusWorktree(worktreePath) }

        let previous = focusedWorktree
        let worktreeId = SupacodeCommand.identifier(forPath: worktreePath)
        focusedWorktree = worktreeId

        do {
            try await supacode(SupacodeCommand.focusSurface(
                worktreeId: worktreeId,
                tabId: tab,
                surfaceId: surface
            ))
            _ = activator.activate(bundleIdentifier: Supacode.bundleIdentifier)
        } catch {
            focusedWorktree = previous
            report(error)
        }
    }

    func applyJira(columns jiraColumns: [JiraColumn], issues: [JiraIssue], allIssues: [JiraIssue] = []) async {
        self.jiraColumns = jiraColumns
        self.issues = issues
        unfilteredIssues = allIssues
        loaded = true
        await refreshTruth()
    }

    func checkToken(email: String) async {
        let runner = runner
        hasToken = await Task.detached {
            JiraCredentials.hasStoredToken(runner: runner, email: email)
        }.value
    }

    func configureJira(
        site: URL,
        email: String,
        projectKey: String,
        jql: String = "",
        runner: CommandRunner = SystemCommandRunner(),
        session: URLSession = .shared
    ) async {
        errorMessage = nil
        do {
            let credentials = try await Task.detached {
                try JiraCredentials.load(runner: runner, site: site, email: email)
            }.value
            let client = JiraClient(credentials: credentials, session: session)

            guard let board = try await client.boards(projectKey: projectKey).first else {
                throw JiraError.boardNotFound(projectKey: projectKey)
            }

            jira = client
            boardId = board.id
            sprintId = try await client.activeSprint(boardId: board.id)?.id
            await refreshJira(jql: jql)
        } catch {
            report(error)
        }
    }

    func refreshJira(jql: String = "") async {
        activeJql = jql
        guard let jira, let boardId else { return }
        do {
            let visible = try await jira.issues(boardId: boardId, sprintId: sprintId, jql: jql)
            let everything = jql.trimmingCharacters(in: .whitespaces).isEmpty
                ? visible
                : try await jira.issues(boardId: boardId, sprintId: sprintId, jql: "")

            await applyJira(
                columns: try await jira.columns(boardId: boardId),
                issues: visible,
                allIssues: everything
            )
        } catch {
            report(error)
        }
    }

    func startWork(on card: Card, repositoryPath: String, branch: String, baseBranch: String) {
        guard card.worktreePath == nil, !repositoryPath.isEmpty, !branch.isEmpty else { return }

        guard let dialog = SupacodeCommand.newWorktree(
            repoId: SupacodeCommand.identifier(forPath: repositoryPath),
            branch: branch,
            base: StartWork.base(baseBranch)
        ), opener.open(dialog) else {
            errorMessage = "Supacode did not open its new-worktree dialog"
            return
        }

        _ = activator.activate(bundleIdentifier: Supacode.bundleIdentifier)
    }

    func openInBrowser(_ url: URL) {
        guard opener.open(url) else {
            errorMessage = "Could not open \(url.absoluteString)"
            return
        }
    }

    func loadTransitions(for card: Card) async -> [JiraTransition] {
        guard let jira, let key = card.issueKey else { return [] }
        do {
            return try await jira.transitions(issueKey: key)
        } catch {
            report(error)
            return []
        }
    }

    func apply(_ transition: JiraTransition, to card: Card) async {
        guard let jira, let key = card.issueKey else { return }
        do {
            try await jira.applyTransition(issueKey: key, transitionId: transition.id)
            await refreshJira(jql: activeJql)
        } catch {
            report(error)
        }
    }

    private func report(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    @discardableResult
    private nonisolated func supacode(_ arguments: [String]) async throws -> String {
        let driver = driver
        return try await Task.detached { try driver.run(arguments) }.value
    }
}
