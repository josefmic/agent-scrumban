import XCTest
@testable import ScrumbanCore

final class ProcessTableTests: XCTestCase {
    private let sample = """
      100     1 /bin/zsh
      200   100 /usr/local/bin/claude
      300   100 /usr/bin/vim notes.txt
      400   999 /usr/local/bin/claude
    """

    func testParsesPidParentAndCommand() {
        let processes = ProcessTableParser.parse(sample)

        XCTAssertEqual(processes.count, 4)
        XCTAssertEqual(processes[0].pid, 100)
        XCTAssertEqual(processes[0].parentPid, 1)
        XCTAssertEqual(processes[2].command, "/usr/bin/vim notes.txt")
    }

    func testDescendantsWalksTheWholeSubtree() {
        let tree = ProcessTree(processes: ProcessTableParser.parse(sample))

        let pids = tree.descendants(of: 100).map(\.pid).sorted()

        XCTAssertEqual(pids, [200, 300])
    }

    func testDescendantsOfUnknownPidIsEmpty() {
        let tree = ProcessTree(processes: ProcessTableParser.parse(sample))

        XCTAssertTrue(tree.descendants(of: 55555).isEmpty)
    }

    func testDetectsClaudeByExecutableName() {
        XCTAssertTrue(AgentDetector.isAgent(RunningProcess(pid: 1, parentPid: 0, command: "/usr/local/bin/claude")))
        XCTAssertTrue(AgentDetector.isAgent(RunningProcess(pid: 1, parentPid: 0, command: "claude --resume")))
    }

    func testDoesNotDetectUnrelatedCommands() {
        XCTAssertFalse(AgentDetector.isAgent(RunningProcess(pid: 1, parentPid: 0, command: "/usr/bin/vim claude.md")))
        XCTAssertFalse(AgentDetector.isAgent(RunningProcess(pid: 1, parentPid: 0, command: "/Applications/Claude.app/Contents/MacOS/Claude")))
    }

    func testNamesTheHarnessItFound() {
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "/usr/local/bin/claude")), .claude)
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "codex --full-auto")), .codex)
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "/opt/homebrew/bin/copilot")), .copilot)
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "aider")), .aider)
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "/usr/bin/opencode run")), .opencode)
        XCTAssertEqual(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "gemini")), .gemini)
    }

    func testNamesNoHarnessForAnUnrelatedProcess() {
        XCTAssertNil(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "/usr/bin/vim codex.md")))
        XCTAssertNil(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "/Applications/Claude.app/Contents/MacOS/Claude")))
        XCTAssertNil(AgentDetector.kind(of: RunningProcess(pid: 1, parentPid: 0, command: "")))
    }
}
