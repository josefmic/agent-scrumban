import XCTest
import ScrumbanCore
@testable import AgentScrumban

@MainActor
final class JiraConnectionTests: XCTestCase {
    func testReportsAMissingKeychainTokenInsteadOfFailingSilently() async {
        let runner = RecordingRunner(outputs: ["security": "\n"])
        let model = BoardViewModel(runner: runner)

        await model.configureJira(
            site: URL(string: "https://example.atlassian.net")!,
            email: "a@b.cz",
            projectKey: "ABC",
            runner: runner
        )

        XCTAssertNotNil(model.errorMessage)
    }

    func testLooksTheTokenUpUnderTheAgentScrumbanService() async {
        let runner = RecordingRunner(outputs: ["security": "tok\n"])
        let model = BoardViewModel(runner: runner)

        await model.configureJira(
            site: URL(string: "https://example.atlassian.net")!,
            email: "a@b.cz",
            projectKey: "ABC",
            runner: runner
        )

        let lookup = runner.calls.first { $0.executable.hasSuffix("security") }
        XCTAssertEqual(
            lookup?.arguments,
            ["find-generic-password", "-a", "a@b.cz", "-s", "agent-scrumban", "-w"]
        )
    }

    func testSettingsKeysAreStable() {
        XCTAssertEqual(SettingsKey.site, "jiraSite")
        XCTAssertEqual(SettingsKey.email, "jiraEmail")
        XCTAssertEqual(SettingsKey.projectKey, "jiraProjectKey")
        XCTAssertEqual(SettingsKey.repositoryPath, "repositoryPath")
        XCTAssertEqual(SettingsKey.baseBranch, "baseBranch")
    }
}
