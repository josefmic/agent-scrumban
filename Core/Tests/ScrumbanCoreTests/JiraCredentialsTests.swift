import XCTest
@testable import ScrumbanCore

final class JiraCredentialsTests: XCTestCase {
    func testStoresTheTokenUnderTheServiceTheReaderLooksUp() throws {
        let runner = RecordingRunner()

        try JiraCredentials.storeToken(runner: runner, email: "a@b.cz", token: "dummy")

        XCTAssertEqual(
            runner.calls.first?.arguments,
            ["add-generic-password", "-U", "-a", "a@b.cz", "-s", "agent-scrumban", "-w", "dummy"]
        )
    }

    func testRemovesTheTokenForOneAccount() throws {
        let runner = RecordingRunner()

        try JiraCredentials.removeToken(runner: runner, email: "a@b.cz")

        XCTAssertEqual(
            runner.calls.first?.arguments,
            ["delete-generic-password", "-a", "a@b.cz", "-s", "agent-scrumban"]
        )
    }

    func testReportsAStoredToken() {
        let lookup = ["find-generic-password", "-a", "a@b.cz", "-s", "agent-scrumban", "-w"]
        let runner = RecordingRunner(outputs: [lookup: "dummy\n"])

        XCTAssertTrue(JiraCredentials.hasStoredToken(runner: runner, email: "a@b.cz"))
    }

    func testReportsNoTokenWhenTheKeychainAnswersEmpty() {
        XCTAssertFalse(JiraCredentials.hasStoredToken(runner: RecordingRunner(), email: "a@b.cz"))
    }

    func testDoesNotTouchTheKeychainWithoutAnEmail() {
        let runner = RecordingRunner()

        XCTAssertFalse(JiraCredentials.hasStoredToken(runner: runner, email: ""))
        XCTAssertTrue(runner.calls.isEmpty)
    }
}
