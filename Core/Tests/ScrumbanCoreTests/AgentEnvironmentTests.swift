import XCTest
@testable import ScrumbanCore

final class AgentEnvironmentTests: XCTestCase {
    func testReadsTheTabEachAgentWasStartedIn() {
        let listing = "  11663 claude TERM_PROGRAM=supacode SUPACODE_TAB_ID=53FFA90A-2769 PWD=/w/one\n"
            + "  50552 claude SUPACODE_TAB_ID=60A33F71-6374 SUPACODE_SURFACE_ID=1554ECD5\n"

        XCTAssertEqual(
            AgentEnvironment.parse(listing),
            [11663: "53FFA90A-2769", 50552: "60A33F71-6374"]
        )
    }

    func testSkipsAProcessWhoseEnvironmentIsUnreadable() {
        XCTAssertTrue(AgentEnvironment.parse("  22101 /usr/bin/login -flp user /bin/bash\n").isEmpty)
    }

    func testAsksForNothingWhenNoAgentIsRunning() {
        let runner = RecordingRunner()

        XCTAssertTrue(AgentEnvironment.tabs(ofProcesses: [], runner: runner).isEmpty)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testAsksForEveryAgentInOneCall() {
        let arguments = ["-wwE", "-o", "pid=,command=", "-p", "200,500"]
        let runner = RecordingRunner(outputs: [arguments: "  200 claude SUPACODE_TAB_ID=TAB-A\n"])

        XCTAssertEqual(AgentEnvironment.tabs(ofProcesses: [200, 500], runner: runner), [200: "TAB-A"])
        XCTAssertEqual(runner.calls, [Call(executable: "/bin/ps", arguments: arguments)])
    }
}
