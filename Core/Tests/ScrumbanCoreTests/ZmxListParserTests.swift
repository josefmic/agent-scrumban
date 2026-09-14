import XCTest
@testable import ScrumbanCore

final class ZmxListParserTests: XCTestCase {
    func testParsesSessionFields() {
        let output = "  name=supa-abc\tpid=70382\tclients=1\tcreated=1788954756\tstart_dir=/Users/j/repo\tcmd=/usr/bin/login -flp j\n"

        let sessions = ZmxListParser.parse(output)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].name, "supa-abc")
        XCTAssertEqual(sessions[0].pid, 70382)
        XCTAssertEqual(sessions[0].clients, 1)
        XCTAssertEqual(sessions[0].startDirectory, "/Users/j/repo")
        XCTAssertFalse(sessions[0].focused)
    }

    func testMarksFocusedSession() {
        let output = "→ name=supa-abc\tpid=1\tclients=1\tstart_dir=/x\tcmd=zsh\n"

        XCTAssertTrue(ZmxListParser.parse(output)[0].focused)
    }

    func testSkipsLinesWithoutRequiredFields() {
        let output = "garbage\n\nname=only-a-name\tclients=1\n"

        XCTAssertTrue(ZmxListParser.parse(output).isEmpty)
    }

    func testParsesPathsContainingSpaces() {
        let output = "  name=s\tpid=2\tclients=0\tstart_dir=/Users/j/My Repos/app\tcmd=zsh\n"

        XCTAssertEqual(ZmxListParser.parse(output)[0].startDirectory, "/Users/j/My Repos/app")
    }
}
