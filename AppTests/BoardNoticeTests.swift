import XCTest
import SwiftUI
import ViewInspector
@testable import AgentScrumban

@MainActor
final class BoardNoticeTests: XCTestCase {
    func testTheLoadingNoticeSpinsAndSaysWhatItIsWaitingFor() throws {
        let sut = LoadingNotice()

        XCTAssertNoThrow(try sut.inspect().find(ViewType.ProgressView.self))
        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("Jira") }))
    }

    func testTheSetupNoticeNamesWhatIsStillMissing() throws {
        let sut = SetupNotice(missing: [.site, .token])

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in
            text.contains("Site") && text.contains("API token")
        }))
    }

    func testTheSetupNoticeSaysWhyJiraIsNeeded() throws {
        let sut = SetupNotice(missing: [.token])

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("API token") }))
        XCTAssertNoThrow(try sut.inspect().find(ViewType.ContentUnavailableView.self))
    }

    func testAnEmptySprintIsExplainedRatherThanLeftBlank() throws {
        let sut = EmptyNotice(reason: .noIssues)

        XCTAssertNoThrow(try sut.inspect().find(text: "No issues in this sprint"))
    }

    func testAFilterThatHidesEverythingSaysSo() throws {
        let sut = EmptyNotice(reason: .hiddenByFilter)

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("filter") }))
    }

    func testNoWorktreesAtAllIsExplained() throws {
        let sut = EmptyNotice(reason: .noWorktrees)

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("worktree") }))
    }

    func testABoardWithoutColumnsIsExplained() throws {
        let sut = EmptyNotice(reason: .noColumns)

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("column") }))
    }

    func testTheFailureNoticeShowsWhatJiraSaid() throws {
        let sut = FailureNotice(message: "The operation couldn’t be completed", onRetry: {})

        XCTAssertNoThrow(try sut.inspect().find(text: "The operation couldn’t be completed"))
    }

    func testTheFailureNoticeOffersARetry() throws {
        var retried = false
        let sut = FailureNotice(message: "boom", onRetry: { retried = true })

        try sut.inspect().find(button: "Try again").tap()

        XCTAssertTrue(retried)
    }
}
