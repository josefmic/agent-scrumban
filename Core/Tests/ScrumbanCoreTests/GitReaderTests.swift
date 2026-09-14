import XCTest
@testable import ScrumbanCore

private struct ThrowingRunner: CommandRunner {
    func run(_ executable: String, _ arguments: [String]) throws -> String {
        throw CommandError.failed(executable: executable, arguments: arguments, status: 128, standardError: "not a git repository")
    }
}

private struct ScriptedRunner: CommandRunner {
    let outputs: [[String]: String]

    func run(_ executable: String, _ arguments: [String]) throws -> String {
        outputs[arguments] ?? ""
    }
}

final class GitReaderTests: XCTestCase {
    func testBranchIsNilForAPathThatIsNotARepository() {
        XCTAssertNil(GitReader(runner: ThrowingRunner()).branch(at: "/w/plain"))
    }

    func testDiffstatIsZeroForAPathThatIsNotARepository() {
        XCTAssertEqual(GitReader(runner: ThrowingRunner()).diffstat(at: "/w/plain"), DiffStat(added: 0, removed: 0))
    }

    func testDiffstatCountsWorkCommittedOnTheBranch() {
        let reader = GitReader(runner: ScriptedRunner(outputs: [
            ["-C", "/w/one", "merge-base", "HEAD", "main"]: "abc123\n",
            ["-C", "/w/one", "diff", "--shortstat", "abc123"]: " 3 files changed, 12 insertions(+), 4 deletions(-)\n",
            ["-C", "/w/one", "diff", "--shortstat", "HEAD"]: "",
        ]))

        XCTAssertEqual(reader.diffstat(at: "/w/one"), DiffStat(added: 12, removed: 4))
    }

    func testDiffstatFallsBackToTheWorkingTreeWithoutAForkPoint() {
        let reader = GitReader(runner: ScriptedRunner(outputs: [
            ["-C", "/w/one", "diff", "--shortstat", "HEAD"]: " 1 file changed, 7 insertions(+)\n",
        ]))

        XCTAssertEqual(reader.diffstat(at: "/w/one"), DiffStat(added: 7, removed: 0))
    }

    func testRunsTheExpectedBranchCommand() {
        let runner = RecordingRunner()

        _ = GitReader(runner: runner).branch(at: "/w/one")

        XCTAssertEqual(runner.calls, [Call(executable: "/usr/bin/git", arguments: ["-C", "/w/one", "branch", "--show-current"])])
    }

    func testRunsTheExpectedDiffstatCommands() {
        let runner = RecordingRunner(outputs: [["-C", "/w/one", "merge-base", "HEAD", "main"]: "abc123\n"])

        _ = GitReader(runner: runner).diffstat(at: "/w/one", baseBranch: "main")

        XCTAssertEqual(runner.calls, [
            Call(executable: "/usr/bin/git", arguments: ["-C", "/w/one", "merge-base", "HEAD", "main"]),
            Call(executable: "/usr/bin/git", arguments: ["-C", "/w/one", "diff", "--shortstat", "abc123"]),
        ])
    }
}
