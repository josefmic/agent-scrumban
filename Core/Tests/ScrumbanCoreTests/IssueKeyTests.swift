import XCTest
@testable import ScrumbanCore

private struct FixedRunner: CommandRunner {
    let output: String
    func run(_ executable: String, _ arguments: [String]) throws -> String { output }
}

final class IssueKeyTests: XCTestCase {
    func testExtractsKeyFromConventionalBranch() {
        XCTAssertEqual(IssueKey.extract(fromBranch: "f/ABC-1336-shopify-reinstall"), "ABC-1336")
    }

    func testExtractsKeyWithoutPrefix() {
        XCTAssertEqual(IssueKey.extract(fromBranch: "ABC-639"), "ABC-639")
    }

    func testReturnsNilForBranchWithoutKey() {
        XCTAssertNil(IssueKey.extract(fromBranch: "f/storybook-deploy"))
        XCTAssertNil(IssueKey.extract(fromBranch: "main"))
    }

    func testIgnoresLowercaseAndPartialMatches() {
        XCTAssertNil(IssueKey.extract(fromBranch: "f/abc-1336-x"))
        XCTAssertNil(IssueKey.extract(fromBranch: "f/ABC-abc"))
    }

    func testReadsBranchName() throws {
        let reader = GitReader(runner: FixedRunner(output: "f/ABC-1326-figma-sync\n"))

        XCTAssertEqual(try reader.branch(at: "/w/one"), "f/ABC-1326-figma-sync")
    }

    func testReadsDiffstat() throws {
        let reader = GitReader(runner: FixedRunner(output: " 3 files changed, 82 insertions(+), 14 deletions(-)\n"))

        let stat = try reader.diffstat(at: "/w/one")

        XCTAssertEqual(stat.added, 82)
        XCTAssertEqual(stat.removed, 14)
    }

    func testDiffstatIsZeroWhenNothingChanged() throws {
        let reader = GitReader(runner: FixedRunner(output: "\n"))

        let stat = try reader.diffstat(at: "/w/one")

        XCTAssertEqual(stat.added, 0)
        XCTAssertEqual(stat.removed, 0)
    }
}
