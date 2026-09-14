import XCTest
import ScrumbanCore
import os
@testable import AgentScrumban

final class RecordingActivator: AppActivating, @unchecked Sendable {
    private let lock = NSLock()
    private var raised: [String] = []

    var activated: [String] {
        lock.withLock { raised }
    }

    func activate(bundleIdentifier: String) -> Bool {
        lock.withLock { raised.append(bundleIdentifier) }
        return true
    }
}

final class RecordingRunner: CommandRunner, Sendable {
    private let outputs: [String: String]
    private let scripted: (@Sendable ([String]) -> String?)?
    private let recordedCalls = OSAllocatedUnfairLock(initialState: [(executable: String, arguments: [String])]())

    var calls: [(executable: String, arguments: [String])] { recordedCalls.withLock { $0 } }

    init(outputs: [String: String] = [:], scripted: (@Sendable ([String]) -> String?)? = nil) {
        self.outputs = outputs
        self.scripted = scripted
    }

    func run(_ executable: String, _ arguments: [String]) throws -> String {
        recordedCalls.withLock { $0.append((executable, arguments)) }
        if let answer = scripted?(arguments) { return answer }
        return outputs[(executable as NSString).lastPathComponent] ?? ""
    }
}

struct FailingRunner: CommandRunner {
    struct Boom: Error {}
    func run(_ executable: String, _ arguments: [String]) throws -> String { throw Boom() }
}

@MainActor
final class BoardViewModelTests: XCTestCase {
    private let lane = [JiraColumn(name: "In Progress", statusIds: ["3"])]
    private let issue = [JiraIssue(key: "ABC-7", summary: "Thing", statusId: "3", statusName: "In Progress")]

    private func runner(agentAlive: Bool, focused: String = "") -> RecordingRunner {
        RecordingRunner(
            outputs: [
                "zmx": "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
                "ps": agentAlive
                    ? "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n"
                    : "100 1 /bin/zsh\n",
                "supacode": focused,
            ],
            scripted: { arguments in
                Array(arguments.prefix(2)) == ["-C", "/w/one"] ? "f/ABC-7-thing\n" : nil
            }
        )
    }

    private func board(_ recording: RecordingRunner, activator: AppActivating = RecordingActivator()) async -> BoardViewModel {
        let model = BoardViewModel(activator: activator, runner: recording)
        await model.applyJira(columns: lane, issues: issue)
        return model
    }

    private func card(_ model: BoardViewModel) -> Card {
        model.columns.flatMap(\.cards)[0]
    }

    func testKeepsAWorktreeWithNoJiraIssueOffTheBoard() async {
        let model = BoardViewModel(runner: runner(agentAlive: true))

        await model.applyJira(columns: lane, issues: [])

        XCTAssertEqual(model.columns.map(\.name), ["In Progress"])
        XCTAssertTrue(model.columns.allSatisfy { $0.cards.isEmpty })
    }

    func testReportsIdleForALiveAgentWithNoTranscript() async {
        let model = await board(runner(agentAlive: true))

        XCTAssertEqual(card(model).sessions.first?.activity, .idle)
    }

    func testReportsWorkingWhileTheScreenShowsATurnInFlight() async {
        let bar = String(repeating: "\u{2500}", count: 40)
        let inFlight = "\(bar)\n\u{276F}\n\(bar)\n  \u{23F5}\u{23F5} auto mode on (shift+tab to cycle) \u{B7} esc to interrupt\n"
        let recording = RecordingRunner(
            outputs: [
                "zmx": "  name=supa-a\tpid=100\tclients=1\tstart_dir=/w/one\tcmd=zsh\n",
                "ps": "100 1 /bin/zsh\n200 100 /usr/local/bin/claude\n",
            ],
            scripted: { arguments in
                if arguments.first == "history" { return inFlight }
                return Array(arguments.prefix(2)) == ["-C", "/w/one"] ? "f/ABC-7-thing\n" : nil
            }
        )

        let model = await board(recording)

        XCTAssertEqual(card(model).sessions.first?.activity, .working)
    }

    func testReportsNoAgentAtAllWhenNoSessionIsOpen() async {
        let model = await board(runner(agentAlive: false))

        XCTAssertNil(card(model).sessions.first?.activity)
    }

    func testReadsTheBranchForEachWorktree() async {
        let model = await board(runner(agentAlive: true))

        XCTAssertEqual(card(model).branch, "f/ABC-7-thing")
    }

    func testSurfacesAnErrorInsteadOfCrashing() async {
        let model = BoardViewModel(runner: FailingRunner())

        await model.refreshTruth()

        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.columns.isEmpty)
    }

    func testMarksTheWorktreeSupacodeReportsAsFocused() async {
        let model = await board(runner(agentAlive: true, focused: "%2Fw%2Fone%2F\n"))

        XCTAssertEqual(model.focusedWorktree, "%2Fw%2Fone%2F")
        XCTAssertTrue(model.isFocused(card(model)))
    }

    func testMarksNothingWhenSupacodeReportsADifferentWorktree() async {
        let model = await board(runner(agentAlive: true, focused: "%2Fw%2Ftwo%2F\n"))

        XCTAssertFalse(model.isFocused(card(model)))
    }

    func testMarksNothingWhenSupacodeReportsNoFocus() async {
        let model = await board(runner(agentAlive: true))

        XCTAssertNil(model.focusedWorktree)
        XCTAssertFalse(model.isFocused(card(model)))
    }

    func testAskedSupacodeForTheFocusedWorktreeOffTheMainActor() async {
        let recording = runner(agentAlive: true, focused: "%2Fw%2Fone%2F\n")
        let model = BoardViewModel(runner: recording)

        await model.refreshTruth()

        XCTAssertTrue(recording.calls.contains { $0.arguments == ["worktree", "list", "--focused"] })
    }

    func testFocusingOneSessionGoesStraightToTheTabItRunsIn() async {
        let recording = RecordingRunner()
        let activator = RecordingActivator()
        let model = BoardViewModel(activator: activator, runner: recording)

        await model.focus(
            AgentSession(name: "supa-cc376a89-4c13-4a62-9a9f-136d7dd3c9cf", tab: "TAB-B"),
            in: "/w/one"
        )

        XCTAssertEqual(recording.calls.map(\.arguments), [[
            "surface", "focus", "-w", "%2Fw%2Fone%2F", "-t", "TAB-B", "-s", "CC376A89-4C13-4A62-9A9F-136D7DD3C9CF",
        ]])
        XCTAssertEqual(activator.activated, ["app.supabit.supacode"])
        XCTAssertNil(model.errorMessage)
    }

    func testFocusingASessionWithNoKnownTabFallsBackToItsWorktree() async {
        let recording = RecordingRunner()
        let model = BoardViewModel(runner: recording)

        await model.focus(AgentSession(name: "supa-cc376a89"), in: "/w/one")

        XCTAssertEqual(recording.calls.map(\.arguments), [["worktree", "focus", "-w", "%2Fw%2Fone%2F"]])
    }

    func testMovesTheFocusTintWithoutWaitingForThePoll() async {
        let model = await board(runner(agentAlive: true, focused: "%2Fw%2Ftwo%2F\n"))

        await model.focus(card(model))

        XCTAssertEqual(model.focusedWorktree, "%2Fw%2Fone%2F")
    }

    func testPutsTheFocusTintBackWhenSupacodeRefuses() async {
        let model = BoardViewModel(runner: FailingRunner())
        let card = Card(
            columnName: "In Progress",
            issueKey: "ABC-9",
            summary: "Nine",
            worktreePath: "/w/one",
            branch: nil,
            diffstat: nil
        )

        await model.focus(card)

        XCTAssertNil(model.focusedWorktree)
        XCTAssertNotNil(model.errorMessage)
    }

    func testIgnoresASessionSupacodeDidNotStart() async {
        let recording = runner(agentAlive: true)
        let model = BoardViewModel(runner: recording)

        await model.focus(AgentSession(name: "scratch"), in: "/w/one")

        XCTAssertTrue(recording.calls.isEmpty)
    }

    func testFocusInvokesSupacodeWithThePercentEncodedWorktree() async {
        let recording = runner(agentAlive: true)
        let model = await board(recording)

        await model.focus(card(model))

        let focusCall = recording.calls.first { $0.arguments.prefix(2) == ["worktree", "focus"] }
        XCTAssertEqual(focusCall?.arguments, ["worktree", "focus", "-w", "%2Fw%2Fone%2F"])
    }

    func testRefreshTruthMeasuresDiffstatAgainstTheConfiguredBaseBranch() async {
        let recording = runner(agentAlive: true)
        let model = BoardViewModel(runner: recording)
        model.baseBranch = "release"

        await model.refreshTruth()

        let mergeBase = recording.calls.first { $0.arguments.contains("merge-base") }
        XCTAssertEqual(mergeBase?.arguments, ["-C", "/w/one", "merge-base", "HEAD", "release"])
    }

    func testReusesCachedGitDataForAnUnchangedWorktreeSet() async {
        let recording = runner(agentAlive: true)
        let model = BoardViewModel(runner: recording)

        await model.refreshTruth()
        let afterFirstPass = recording.calls.filter { $0.executable.hasSuffix("git") }.count
        await model.refreshTruth()

        XCTAssertEqual(recording.calls.filter { $0.executable.hasSuffix("git") }.count, afterFirstPass)
    }

    func testFocusDoesNothingForACardWithoutAWorktree() async {
        let recording = runner(agentAlive: true)
        let model = BoardViewModel(runner: recording)
        let detached = Card(
            columnName: "In Progress",
            issueKey: "ABC-9",
            summary: "No worktree",
            worktreePath: nil,
            branch: nil,
            diffstat: nil
        )
        let before = recording.calls.count

        await model.focus(detached)

        XCTAssertEqual(recording.calls.count, before)
    }

    func testFocusActivatesTheSupacodeApplication() async {
        let activator = RecordingActivator()
        let model = await board(runner(agentAlive: true), activator: activator)

        await model.focus(card(model))

        XCTAssertEqual(activator.activated, ["app.supabit.supacode"])
    }

    func testFocusDoesNotActivateWithoutAWorktree() async {
        let activator = RecordingActivator()
        let model = BoardViewModel(activator: activator, runner: runner(agentAlive: true))

        await model.focus(Card(
            columnName: "In Progress",
            issueKey: "ABC-9",
            summary: "No worktree",
            worktreePath: nil,
            branch: nil,
            diffstat: nil
        ))

        XCTAssertTrue(activator.activated.isEmpty)
    }
}
