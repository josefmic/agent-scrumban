import Foundation

public struct AgentSession: Equatable, Sendable, Identifiable {
    public let name: String
    public let pid: Int32?
    public let harness: AgentKind?
    public let activity: AgentActivity?
    public let created: Date?
    public let tab: String?

    public init(
        name: String,
        pid: Int32? = nil,
        harness: AgentKind? = nil,
        activity: AgentActivity? = nil,
        created: Date? = nil,
        tab: String? = nil
    ) {
        self.name = name
        self.pid = pid
        self.harness = harness
        self.activity = activity
        self.created = created
        self.tab = tab
    }

    public var id: String { name }
}

public struct WorktreeState: Equatable, Sendable {
    public let path: String
    public let sessions: [AgentSession]

    public init(path: String, sessions: [AgentSession]) {
        self.path = path
        self.sessions = sessions
    }
}
public struct TruthService: Sendable {
    public static let defaultZmxPath = ProcessInfo.processInfo.environment["SCRUMBAN_ZMX"]
        ?? "/Applications/supacode.app/Contents/Resources/zmx/zmx"

    private let runner: CommandRunner
    private let zmxPath: String
    private let supacode: SupacodeDriver
    private var transcripts: TranscriptStore
    private var tabSessions: TabSessionLog

    public init(
        runner: CommandRunner,
        zmxPath: String = TruthService.defaultZmxPath,
        supacodePath: String = SupacodeDriver.defaultExecutablePath,
        transcriptRoot: URL = TranscriptStore.defaultRoot,
        tabSessionLog: URL = TabSessionLog.defaultURL
    ) {
        self.runner = runner
        self.zmxPath = zmxPath
        supacode = SupacodeDriver(runner: runner, executablePath: supacodePath)
        transcripts = TranscriptStore(root: transcriptRoot)
        tabSessions = TabSessionLog(url: tabSessionLog)
    }

    public mutating func snapshot() throws -> [WorktreeState] {
        let worktrees = SupacodeCommand.identifiers(in: try supacode.run(["worktree", "list"]))
            .compactMap(SupacodeCommand.path(forIdentifier:))
        let sessions = ZmxListParser.parse(try runner.run(zmxPath, ["list"]))
        let table = ProcessTableParser.parse(try runner.run("/bin/ps", ["-axo", "pid=,ppid=,command="]))
        let tree = ProcessTree(processes: table)

        let live = sessions.map { session -> (session: ZmxSession, path: String, agent: RunningProcess?) in
            let agent = tree.descendants(of: session.pid).first(where: AgentDetector.isAgent)
            let directory = session.startDirectory
            let path = directory.count > 1 && directory.hasSuffix("/") ? String(directory.dropLast()) : directory
            return (session, path, agent)
        }

        var claudeCount: [String: Int] = [:]
        for entry in live where entry.agent.flatMap(AgentDetector.kind) == .claude {
            claudeCount[entry.path, default: 0] += 1
        }

        let tabs = AgentEnvironment.tabs(
            ofProcesses: live.compactMap { entry in
                entry.agent.flatMap { AgentDetector.kind(of: $0) == .claude ? $0.pid : nil }
            },
            runner: runner
        )

        var paths = worktrees
        var grouped: [String: [AgentSession]] = worktrees.reduce(into: [:]) { $0[$1] = [] }

        for entry in live {
            let harness = entry.agent.flatMap(AgentDetector.kind)
            let tab = entry.agent.flatMap { tabs[$0.pid] }

            var activity: AgentActivity?
            if let harness {
                activity = harness == .claude
                    ? transcripts.activity(
                        forWorktreePath: entry.path,
                        lookup: lookup(tab: tab, sole: claudeCount[entry.path] == 1),
                        working: isWorking(session: entry.session.name)
                    )
                    : .idle
            }

            if grouped[entry.path] == nil { paths.append(entry.path) }
            grouped[entry.path, default: []].append(AgentSession(
                name: entry.session.name,
                pid: entry.agent?.pid,
                harness: harness,
                activity: activity,
                created: entry.session.created,
                tab: tab
            ))
        }

        return paths.map { WorktreeState(path: $0, sessions: grouped[$0] ?? []) }
    }

    private func isWorking(session: String) -> Bool {
        guard let screen = try? runner.run(zmxPath, ["history", session, "--vt"]) else { return false }

        return SessionScreen.isWorking(screen)
    }

    private mutating func lookup(tab: String?, sole: Bool) -> TranscriptLookup {
        if let sessionId = tab.flatMap({ tabSessions.sessionId(forTab: $0) }) { return .session(sessionId) }
        return sole ? .soleSessionInWorktree : .unresolved
    }
}
