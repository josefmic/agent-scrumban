import XCTest
import ScrumbanCore
@testable import AgentScrumban

final class JiraSetupTests: XCTestCase {
    func testReportsEverySettingAsMissingOnAFreshInstall() {
        let setup = JiraSetup(site: "", email: "", projectKey: "", hasToken: false)

        XCTAssertEqual(setup.missing, [.site, .email, .projectKey, .token])
    }

    func testCountsWhitespaceAsMissing() {
        let setup = JiraSetup(site: "  ", email: " ", projectKey: "\t", hasToken: true)

        XCTAssertEqual(setup.missing, [.site, .email, .projectKey])
    }

    func testRejectsASiteThatIsNotAnAddress() {
        let setup = JiraSetup(site: "example.atlassian.net", email: "a@b.cz", projectKey: "ABC", hasToken: true)

        XCTAssertEqual(setup.missing, [.site])
    }

    func testAsksOnlyForTheTokenWhenTheRestIsFilledIn() {
        let setup = JiraSetup(site: "https://example.atlassian.net", email: "a@b.cz", projectKey: "ABC", hasToken: false)

        XCTAssertEqual(setup.missing, [.token])
    }

    func testAcceptsACompleteSetupAndHandsBackTheSiteURL() {
        let setup = JiraSetup(site: " https://example.atlassian.net ", email: "a@b.cz", projectKey: "ABC", hasToken: true)

        XCTAssertTrue(setup.isComplete)
        XCTAssertEqual(setup.url, URL(string: "https://example.atlassian.net"))
    }
}

final class BoardPhaseTests: XCTestCase {
    private let ready = JiraSetup(site: "https://example.atlassian.net", email: "a@b.cz", projectKey: "ABC", hasToken: true)
    private let blank = JiraSetup(site: "", email: "", projectKey: "", hasToken: false)

    private func column(cards: Int, total: Int) -> BoardColumnModel {
        BoardColumnModel(
            name: "In Progress",
            cards: (0..<cards).map {
                Card(columnName: "In Progress", issueKey: "ABC-\($0)", summary: "Thing", worktreePath: nil, branch: nil, diffstat: nil)
            },
            total: total
        )
    }

    func testAsksForSetupBeforeAnythingElse() {
        let phase = BoardPhase.of(setup: blank, loaded: true, error: "boom", columns: [column(cards: 2, total: 2)], worktrees: 1)

        XCTAssertEqual(phase, .setup([.site, .email, .projectKey, .token]))
    }

    func testShowsLoadingUntilJiraAnswers() {
        XCTAssertEqual(BoardPhase.of(setup: ready, loaded: false, error: nil, columns: [], worktrees: 0), .loading)
    }

    func testShowsTheFailureWhenJiraNeverAnswered() {
        XCTAssertEqual(
            BoardPhase.of(setup: ready, loaded: false, error: "Unauthorized", columns: [], worktrees: 0),
            .failed("Unauthorized")
        )
    }

    func testKeepsTheBoardWhenAnErrorArrivesAfterTheColumnsLoaded() {
        let phase = BoardPhase.of(setup: ready, loaded: true, error: "boom", columns: [column(cards: 1, total: 1)], worktrees: 1)

        XCTAssertEqual(phase, .board)
    }

    func testExplainsABoardJiraReturnedWithNoColumns() {
        XCTAssertEqual(BoardPhase.of(setup: ready, loaded: true, error: nil, columns: [], worktrees: 1), .empty(.noColumns))
    }

    func testExplainsAFilterThatHidesEveryIssue() {
        let phase = BoardPhase.of(setup: ready, loaded: true, error: nil, columns: [column(cards: 0, total: 7)], worktrees: 1)

        XCTAssertEqual(phase, .empty(.hiddenByFilter))
    }

    func testExplainsAnEmptySprintWhileWorktreesAreOpen() {
        let phase = BoardPhase.of(setup: ready, loaded: true, error: nil, columns: [column(cards: 0, total: 0)], worktrees: 2)

        XCTAssertEqual(phase, .empty(.noIssues))
    }

    func testExplainsAnEmptySprintWithNoWorktreesAtAll() {
        let phase = BoardPhase.of(setup: ready, loaded: true, error: nil, columns: [column(cards: 0, total: 0)], worktrees: 0)

        XCTAssertEqual(phase, .empty(.noWorktrees))
    }

    func testShowsTheBoardAsSoonAsAColumnHasCards() {
        let phase = BoardPhase.of(setup: ready, loaded: true, error: nil, columns: [column(cards: 3, total: 9)], worktrees: 0)

        XCTAssertEqual(phase, .board)
    }
}
