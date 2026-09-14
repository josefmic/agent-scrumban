import XCTest
@testable import ScrumbanCore

final class TabSessionLogTests: XCTestCase {
    private var file: URL!

    override func setUpWithError() throws {
        file = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "tabs-\(UUID().uuidString).log")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: file)
    }

    private func write(_ contents: String) throws -> TabSessionLog {
        try Data(contents.utf8).write(to: file)
        return TabSessionLog(url: file)
    }

    func testResolvesATabToItsClaudeSession() throws {
        var log = try write("""
        C07D9D87-98B8-4333-AD3D-6C9C98B60F32 ebd33e13-4dd7-46fc-b60b-ca592cc398e6
        3E1BEE6E-63D7-4397-8D55-853102C866E5 b5732ed2-4176-490c-8a30-769d3de7ea4e

        """)

        XCTAssertEqual(
            log.sessionId(forTab: "3E1BEE6E-63D7-4397-8D55-853102C866E5"),
            "b5732ed2-4176-490c-8a30-769d3de7ea4e"
        )
    }

    func testTheLastEntryForATabWins() throws {
        var log = try write("""
        C07D9D87 first-session
        C07D9D87 second-session

        """)

        XCTAssertEqual(log.sessionId(forTab: "C07D9D87"), "second-session")
    }

    func testReportsNothingForATabThatNeverTookAPrompt() throws {
        var log = try write("C07D9D87 first-session\n")

        XCTAssertNil(log.sessionId(forTab: "60A33F71"))
    }

    func testSeesAMappingWrittenAfterTheFirstRead() throws {
        var log = try write("C07D9D87 first-session\n")
        XCTAssertEqual(log.sessionId(forTab: "C07D9D87"), "first-session")

        try Data("C07D9D87 first-session\n60A33F71 later-session\n".utf8).write(to: file)

        XCTAssertEqual(log.sessionId(forTab: "60A33F71"), "later-session")
    }

    func testForgetsAMappingThatLeavesTheLog() throws {
        var log = try write("C07D9D87 first-session\n60A33F71 later-session\n")
        XCTAssertEqual(log.sessionId(forTab: "60A33F71"), "later-session")

        try Data("C07D9D87 first-session\n".utf8).write(to: file)

        XCTAssertNil(log.sessionId(forTab: "60A33F71"))
    }

    func testResolvesATabRecordedFarFromTheEndOfTheLog() throws {
        let filler = (0..<20_000)
            .map { "TAB-\($0) session-\($0)" }
            .joined(separator: "\n")
        var log = try write("60A33F71 early-session\n" + filler + "\n")

        XCTAssertEqual(log.sessionId(forTab: "60A33F71"), "early-session")
    }

    func testSurvivesAMissingLog() {
        var log = TabSessionLog(url: file)

        XCTAssertNil(log.sessionId(forTab: "C07D9D87"))
    }
}
