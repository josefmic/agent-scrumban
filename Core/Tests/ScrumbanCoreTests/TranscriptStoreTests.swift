import XCTest
@testable import ScrumbanCore

final class TranscriptStoreTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "transcripts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ lines: String, worktree: String = "/w/one", named name: String = "session.jsonl") throws -> URL {
        let directory = root.appending(path: TranscriptStore.directoryName(forWorktreePath: worktree))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        try Data(lines.utf8).write(to: file)
        return file
    }

    private var subject: TranscriptStore { TranscriptStore(root: root) }

    private func stamp(_ secondsAgo: TimeInterval) -> String {
        Date(timeIntervalSinceNow: -secondsAgo).ISO8601Format()
    }

    private func assistant(_ stopReason: String?, secondsAgo: TimeInterval = 0, tools: [String] = []) -> String {
        let reason = stopReason.map { "\"\($0)\"" } ?? "null"
        let content = tools
            .map { #"{"type":"tool_use","id":"t1","name":"\#($0)","input":{}}"# }
            .joined(separator: ",")
        return #"{"type":"assistant","timestamp":"\#(stamp(secondsAgo))","message":{"stop_reason":\#(reason),"content":[\#(content)]}}"#
    }

    private func userTurn(secondsAgo: TimeInterval = 0) -> String {
        #"{"type":"user","timestamp":"\#(stamp(secondsAgo))","message":{"role":"user","content":"hi"}}"#
    }

    private func stopHook(secondsAgo: TimeInterval = 0) -> String {
        #"{"type":"system","subtype":"stop_hook_summary","timestamp":"\#(stamp(secondsAgo))"}"#
    }

    private static let metadata = #"{"type":"cost-state","sessionId":"x","totalCostUSD":1.5}"#

    func testEncodesAWorktreePathAsItsProjectDirectoryName() {
        XCTAssertEqual(
            TranscriptStore.directoryName(forWorktreePath: "/Users/j/.supacode/repos/app/f/ABC-1326-figma-sync"),
            "-Users-j--supacode-repos-app-f-ABC-1326-figma-sync"
        )
    }

    func testAFinishedTurnIsAwaitingInput() throws {
        _ = try write("\(userTurn())\n\(assistant("tool_use"))\n\(assistant("end_turn"))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testAStopHookSummaryEndsTheTurnWithoutACleanEndTurn() throws {
        _ = try write("\(userTurn(secondsAgo: 30))\n\(assistant(nil, secondsAgo: 10))\n\(stopHook())\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testAFinishedTurnStaysWaitingOvernight() throws {
        _ = try write("\(userTurn(secondsAgo: 14_000))\n\(assistant("end_turn", secondsAgo: 13_206))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testTheScreenDecidesWhetherATurnIsInFlight() throws {
        _ = try write("\(userTurn(secondsAgo: 7_200))\n\(assistant("tool_use", secondsAgo: 3_600))\n")

        var store = subject

        XCTAssertEqual(
            store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree, working: true),
            .working
        )
    }

    func testATranscriptMidTurnIsIdleWhileTheScreenShowsNoTurnInFlight() throws {
        for tail in [assistant("tool_use"), assistant(nil), userTurn()] {
            _ = try write("\(assistant("end_turn", secondsAgo: 20))\n\(tail)\n")

            var store = subject

            XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .idle, tail)
        }
    }

    func testANewPromptReadsAsWorkingBeforeTheAssistantWritesAnything() throws {
        _ = try write("\(userTurn(secondsAgo: 60))\n\(assistant("end_turn", secondsAgo: 30))\n")

        var store = subject

        XCTAssertEqual(
            store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree, working: true),
            .working
        )
    }

    func testAQuestionOutranksAScreenThatStillShowsATurnInFlight() throws {
        _ = try write("\(userTurn(secondsAgo: 60))\n\(assistant("tool_use", tools: ["AskUserQuestion"]))\n")

        var store = subject

        XCTAssertEqual(
            store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree, working: true),
            .awaitingInput
        )
    }

    func testEveryToolThatBlocksOnTheUserIsNamed() {
        XCTAssertEqual(Set(BlockingTool.allCases.map(\.rawValue)), ["AskUserQuestion", "ExitPlanMode"])
    }

    func testATurnBlockedOnAUserFacingToolIsAwaitingInput() throws {
        for tool in BlockingTool.allCases {
            _ = try write(
                "\(userTurn(secondsAgo: 60))\n\(assistant("tool_use", tools: [tool.rawValue]))\n",
                worktree: "/w/\(tool.rawValue)"
            )

            var store = subject

            XCTAssertEqual(
                store.activity(forWorktreePath: "/w/\(tool.rawValue)", lookup: .soleSessionInWorktree),
                .awaitingInput,
                tool.rawValue
            )
        }
    }

    func testAQuestionLeftOvernightIsStillAwaitingInput() throws {
        _ = try write("\(userTurn(secondsAgo: 14_000))\n\(assistant("tool_use", secondsAgo: 13_206, tools: ["AskUserQuestion"]))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testABlockingToolAlongsideOthersStillAwaitsInput() throws {
        _ = try write("\(userTurn())\n\(assistant("tool_use", tools: ["Read", "AskUserQuestion"]))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testSkipsMetadataRecordsAtTheTail() throws {
        _ = try write("\(assistant("tool_use"))\n\(assistant("end_turn"))\n\(Self.metadata)\n\(Self.metadata)\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testSkipsATruncatedFinalLine() throws {
        _ = try write("\(userTurn())\n\(assistant("end_turn"))\n{\"type\":\"assist")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testFallsBackToIdleWhenNoMessageEntryExists() throws {
        _ = try write("\(Self.metadata)\n\(Self.metadata)\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .idle)
    }

    func testTrustsTheScreenWhenThereIsNoTranscriptToRead() {
        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/never-started", lookup: .soleSessionInWorktree), .idle)
        XCTAssertEqual(
            store.activity(forWorktreePath: "/w/never-started", lookup: .soleSessionInWorktree, working: true),
            .working
        )
    }

    func testReadsTheMostRecentlyModifiedTranscript() throws {
        let old = try write("\(assistant("end_turn"))\n", named: "old.jsonl")
        let new = try write("\(assistant("tool_use"))\n", named: "new.jsonl")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: new.path)

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .idle)
    }

    func testFindsTheLastMessageEntryBeyondTheFirstWindow() throws {
        let filler = String(repeating: "\(Self.metadata)\n", count: 2_000)
        _ = try write("\(assistant("end_turn"))\n\(filler)")
        XCTAssertGreaterThan(
            try Data(contentsOf: root.appending(path: "-w-one/session.jsonl")).count,
            Int(TranscriptStore.initialWindow)
        )

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testDoesNotRereadAnUnchangedFile() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let finished = assistant("end_turn")
        let file = try write("\(finished)\n")
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        var store = subject
        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)

        let replacement = assistant("tool_use").padding(toLength: finished.count, withPad: " ", startingAt: 0)
        try Data("\(replacement)\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testRereadsAFileWhoseModificationDateMoved() throws {
        let file = try write("\(assistant("end_turn"))\n")
        var store = subject
        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)

        try Data("\(assistant("tool_use"))\n".utf8).write(to: file)

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .idle)
    }

    func testReadsTheTranscriptOfTheSessionItIsAskedAbout() throws {
        _ = try write("\(userTurn())\n\(assistant("end_turn"))\n", named: "newest.jsonl")
        let mine = try write(
            "\(assistant("end_turn", secondsAgo: 4_000))\n\(userTurn(secondsAgo: 3_600))\n",
            named: "mine.jsonl"
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3_600)],
            ofItemAtPath: mine.path
        )

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .session("mine")), .idle)
        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .soleSessionInWorktree), .awaitingInput)
    }

    func testNeverGuessesForASessionItCannotResolve() throws {
        _ = try write("\(userTurn())\n\(assistant("end_turn"))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .unresolved), .idle)
    }

    func testNeverGuessesWhenTheNamedTranscriptIsMissing() throws {
        _ = try write("\(userTurn())\n\(assistant("end_turn"))\n")

        var store = subject

        XCTAssertEqual(store.activity(forWorktreePath: "/w/one", lookup: .session("never-seen")), .idle)
    }
}
