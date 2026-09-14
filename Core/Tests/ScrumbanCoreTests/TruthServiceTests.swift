import XCTest
@testable import ScrumbanCore

private struct StubRunner: CommandRunner {
    let outputs: [String: String]
    var screens: [String: String] = [:]
    var supacode: (@Sendable ([String]) -> String)?
    var environments = ""

    func run(_ executable: String, _ arguments: [String]) throws -> String {
        if let supacode, executable.hasSuffix("supacode") { return supacode(arguments) }
        if arguments.first == "-wwE" { return environments }
        if arguments.first == "history" { return screens[arguments[1]] ?? Screen.parked }
        return outputs[(executable as NSString).lastPathComponent] ?? ""
    }
}

private enum Screen {
    static let bar = String(repeating: "\u{2500}", count: 40)
    static let parked = "\(bar)\n\u{276F}\n\(bar)\n  \u{23F5}\u{23F5} auto mode on (shift+tab to cycle)\n"
    static let inFlight = parked.replacingOccurrences(of: "to cycle)", with: "to cycle) \u{B7} esc to interrupt")
}

final class TruthServiceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "truth-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func service(
        zmx: String,
        ps: String,
        worktrees: String = "",
        screens: [String: String] = [:]
    ) -> TruthService {
        TruthService(
            runner: StubRunner(outputs: ["zmx": zmx, "ps": ps, "supacode": worktrees], screens: screens),
            zmxPath: "/opt/zmx",
            supacodePath: "/opt/supacode",
            transcriptRoot: root
        )
    }

    private func writeTranscript(_ line: String, worktree: String, named name: String = "session") throws {
        let directory = root.appending(path: TranscriptStore.directoryName(forWorktreePath: worktree))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("\(line)\n".utf8).write(to: directory.appending(path: "\(name).jsonl"))
    }

    func testFindsAnAgentThatIsADescendantOfTheSession() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n150 100 /bin/bash\n200 150 /usr/local/bin/claude\n"
        )

        let states = try subject.snapshot()

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0].sessions.map(\.pid), [200])
        XCTAssertEqual(states[0].sessions.first?.harness, .claude)
    }

    func testReportsNoActivityWhenSessionHasNoAgent() throws {
        var subject = service(
            zmx: "  name=supa-b\tpid=100\tclients=1\tstart_dir=/w/two\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n300 100 /usr/bin/vim\n"
        )

        let states = try subject.snapshot()

        XCTAssertNil(states[0].sessions.first?.activity)
        XCTAssertNil(states[0].sessions.first?.pid)
    }

    func testDoesNotAttributeAnAgentFromAnotherSession() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n  name=supa-b\tpid=400\tclients=1\tstart_dir=/w/two\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n400 1 /bin/zsh\n"
        )

        let states = try subject.snapshot()

        XCTAssertEqual(states[0].sessions.first?.pid, 200)
        XCTAssertNil(states[1].sessions.first?.activity)
    }

    func testGathersTwoSessionsRootedInTheSamePathIntoOneWorktree() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/same\tcmd=zsh\n  name=supa-b\tpid=400\tclients=1\tstart_dir=/w/same\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n400 1 /bin/zsh\n"
        )

        let states = try subject.snapshot()

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0].sessions.map(\.name), ["supa-a", "supa-b"])
        XCTAssertEqual(states[0].sessions.first?.pid, 200)
        XCTAssertNil(states[0].sessions.last?.activity)
    }

    func testRunsTheExpectedSessionAndProcessCommands() throws {
        let runner = RecordingRunner()
        var subject = TruthService(runner: runner, zmxPath: "/opt/zmx", transcriptRoot: root)

        _ = try subject.snapshot()

        XCTAssertEqual(runner.calls, [
            Call(executable: SupacodeDriver.defaultExecutablePath, arguments: ["worktree", "list"]),
            Call(executable: "/opt/zmx", arguments: ["list"]),
            Call(executable: "/bin/ps", arguments: ["-axo", "pid=,ppid=,command="]),
        ])
    }

    func testReportsWhichHarnessIsRunning() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /opt/homebrew/bin/codex\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.harness, .codex)
    }

    func testReportsNoHarnessForASessionWithoutAnAgent() throws {
        var subject = service(
            zmx: "  name=supa-b\tpid=100\tclients=1\tstart_dir=/w/two\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n"
        )

        XCTAssertNil(try subject.snapshot()[0].sessions.first?.harness)
    }

    func testReadsClaudeActivityFromItsTranscript() throws {
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#, worktree: "/w/one")
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.activity, .awaitingInput)
    }

    func testReportsIdleForAClaudeSessionWithNoTranscript() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.activity, .idle)
    }

    func testNeverGuessesActivityForANonClaudeHarness() throws {
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#, worktree: "/w/one")
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /opt/homebrew/bin/codex\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.activity, .idle)
    }

    func testAnInterruptedTurnGoesIdleAsSoonAsTheScreenDoes() throws {
        try writeTranscript(#"{"type":"user","message":{"role":"user","content":"go"}}"#, worktree: "/w/one")
        let zmx = "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n"
        let ps = "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n"

        var working = service(zmx: zmx, ps: ps, screens: ["supa-a": Screen.inFlight])
        XCTAssertEqual(try working.snapshot()[0].sessions.first?.activity, .working)

        var interrupted = service(zmx: zmx, ps: ps, screens: ["supa-a": Screen.parked])
        XCTAssertEqual(try interrupted.snapshot()[0].sessions.first?.activity, .idle)
    }

    func testAParkedScreenStillLeavesAFinishedTurnAwaitingInput() throws {
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#, worktree: "/w/one")
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.activity, .awaitingInput)
    }

    func testOnlyReadsTheScreenOfASessionThatHasAnAgent() throws {
        let runner = RecordingRunner(outputs: [
            ["list"]: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n"
                + "  name=supa-b\tpid=400\tclients=1\tstart_dir=/w/two\tcmd=zsh\n",
            ["-axo", "pid=,ppid=,command="]: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n400 1 /bin/zsh\n",
        ])
        var subject = TruthService(
            runner: runner,
            zmxPath: "/opt/zmx",
            supacodePath: "/opt/supacode",
            transcriptRoot: root
        )

        _ = try subject.snapshot()

        XCTAssertEqual(
            runner.calls.filter { $0.arguments.first == "history" }.map { $0.arguments },
            [["history", "supa-a", "--vt"]]
        )
    }

    func testListsAWorktreeThatHasNoSessionOpen() throws {
        var subject = service(
            zmx: "",
            ps: "",
            worktrees: "%2Fw%2FABC-639-dpd-sk-carrier%2F\n"
        )

        let states = try subject.snapshot()

        XCTAssertEqual(states.map(\.path), ["/w/ABC-639-dpd-sk-carrier"])
        XCTAssertTrue(states[0].sessions.isEmpty)
    }

    func testAttachesSessionsToTheWorktreeTheyStartedIn() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n",
            worktrees: "%2Fw%2Fone%2F\n%2Fw%2Ftwo%2F\n"
        )

        let states = try subject.snapshot()

        XCTAssertEqual(states.map(\.path), ["/w/one", "/w/two"])
        XCTAssertEqual(states[0].sessions.map(\.name), ["supa-a"])
        XCTAssertTrue(states[1].sessions.isEmpty)
    }

    func testReadsWhenASessionStarted() throws {
        var subject = service(
            zmx: "  name=supa-a\tpid=100\tclients=1\tcreated=1788954756\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.first?.created, Date(timeIntervalSince1970: 1_788_954_756))
    }

    func testNeverGuessesBetweenTwoSessionsSharingAWorktree() throws {
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#, worktree: "/w/one")
        var subject = service(
            zmx: "  name=supa-aaaaaaaa\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n"
                + "  name=supa-bbbbbbbb\tpid=400\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
            ps: "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n400 1 /bin/zsh\n500 400 /usr/local/bin/claude\n"
        )

        XCTAssertEqual(try subject.snapshot()[0].sessions.map(\.activity), [.idle, .idle])
    }

    func testGivesEachSessionInAWorktreeItsOwnState() throws {
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#, worktree: "/w/one", named: "session-a")
        try writeTranscript(#"{"type":"assistant","message":{"stop_reason":"tool_use"}}"#, worktree: "/w/one", named: "session-b")

        let log = root.appending(path: "tabs.log")
        try Data("TAB-A session-a\nTAB-B session-b\n".utf8).write(to: log)

        let runner = StubRunner(
            outputs: [
                "zmx": "  name=supa-aaaaaaaa\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n"
                    + "  name=supa-bbbbbbbb\tpid=400\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
                "ps": "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n400 1 /bin/zsh\n500 400 /usr/local/bin/claude\n",
            ],
            screens: ["supa-bbbbbbbb": Screen.inFlight],
            supacode: { _ in "%2Fw%2Fone%2F\n" },
            environments: "  200 claude SUPACODE_TAB_ID=TAB-A\n  500 claude SUPACODE_TAB_ID=TAB-B\n"
        )

        var subject = TruthService(
            runner: runner,
            zmxPath: "/opt/zmx",
            supacodePath: "/opt/supacode",
            transcriptRoot: root,
            tabSessionLog: log
        )

        let sessions = try subject.snapshot()[0].sessions

        XCTAssertEqual(sessions.map(\.activity), [.awaitingInput, .working])
        XCTAssertEqual(sessions.map(\.tab), ["TAB-A", "TAB-B"])
    }
}
