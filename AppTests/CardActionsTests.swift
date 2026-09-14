import XCTest
import ScrumbanCore
@testable import AgentScrumban

final class RecordingOpener: URLOpening, @unchecked Sendable {
    private let lock = NSLock()
    private var opened: [URL] = []
    private let answer: Bool

    init(answer: Bool = true) {
        self.answer = answer
    }

    var urls: [URL] { lock.withLock { opened } }

    func open(_ url: URL) -> Bool {
        lock.withLock { opened.append(url) }
        return answer
    }
}

@MainActor
final class CardActionsTests: XCTestCase {
    private func card(worktreePath: String? = nil, summary: String = "Reinstall subscription") -> Card {
        Card(
            columnName: "In Progress",
            issueKey: "ABC-7",
            summary: summary,
            worktreePath: worktreePath,
            branch: nil,
            diffstat: nil
        )
    }

    private func model(opener: URLOpening, activator: AppActivating = RecordingActivator()) -> BoardViewModel {
        BoardViewModel(activator: activator, opener: opener, runner: RecordingRunner())
    }

    func testOpensSupacodesOwnDialogWithTheBranchAlreadyFilledIn() {
        let opener = RecordingOpener()

        model(opener: opener).startWork(
            on: card(),
            repositoryPath: "/Users/j/repo",
            branch: "f/ABC-7-reinstall-subscription",
            baseBranch: "devel"
        )

        XCTAssertEqual(
            opener.urls.map(\.absoluteString),
            ["supacode://repo/%2FUsers%2Fj%2Frepo%2F/worktree/new"
                + "?branch=f%2FABC-7-reinstall-subscription&base=origin%2Fdevel&fetch=true"]
        )
    }

    func testBringsSupacodeForwardAfterOpeningTheDialog() {
        let activator = RecordingActivator()

        model(opener: RecordingOpener(), activator: activator).startWork(
            on: card(),
            repositoryPath: "/Users/j/repo",
            branch: "f/ABC-7-x",
            baseBranch: "devel"
        )

        XCTAssertEqual(activator.activated, ["app.supabit.supacode"])
    }

    func testDoesNothingForACardThatAlreadyHasAWorktree() {
        let opener = RecordingOpener()

        model(opener: opener).startWork(
            on: card(worktreePath: "/w/one"),
            repositoryPath: "/Users/j/repo",
            branch: "f/ABC-7-x",
            baseBranch: "devel"
        )

        XCTAssertTrue(opener.urls.isEmpty)
    }

    func testDoesNothingWithoutARepositoryInSettings() {
        let opener = RecordingOpener()

        model(opener: opener).startWork(
            on: card(),
            repositoryPath: "",
            branch: "f/ABC-7-x",
            baseBranch: "devel"
        )

        XCTAssertTrue(opener.urls.isEmpty)
    }

    func testSaysSoWhenSupacodeWillNotOpenTheDialog() {
        let subject = model(opener: RecordingOpener(answer: false))

        subject.startWork(
            on: card(),
            repositoryPath: "/Users/j/repo",
            branch: "f/ABC-7-x",
            baseBranch: "devel"
        )

        XCTAssertEqual(subject.errorMessage, "Supacode did not open its new-worktree dialog")
    }

    func testTransliteratesACzechSummaryIntoTheBranchItProposes() {
        let opener = RecordingOpener()
        let branch = StartWork.branch(
            template: StartWork.defaultBranchTemplate,
            issueKey: "ABC-1247",
            summary: "První přihlášení stávajícího klienta"
        )

        model(opener: opener).startWork(
            on: card(),
            repositoryPath: "/Users/j/repo",
            branch: branch,
            baseBranch: "devel"
        )

        XCTAssertTrue(
            opener.urls.first?.absoluteString
                .contains("branch=f%2FABC-1247-prvni-prihlaseni-stavajiciho-klienta") ?? false
        )
    }
}
