import XCTest
import SwiftUI
import ViewInspector
import ScrumbanCore
@testable import AgentScrumban

@MainActor
final class StartWorkSheetTests: XCTestCase {
    private func card(key: String? = "ABC-7") -> Card {
        Card(
            columnName: "To Do",
            issueKey: key,
            summary: "První přihlášení stávajícího klienta",
            worktreePath: nil,
            branch: nil,
            diffstat: nil
        )
    }

    private final class Result: @unchecked Sendable {
        var created: [(String, String)] = []
        var cancelled = 0
    }

    private func sheet(_ result: Result, branch: String = "f/ABC-7-x", base: String = "devel") -> StartWorkSheet {
        StartWorkSheet(
            card: card(),
            branch: branch,
            base: base,
            onCreate: { result.created.append(($0, $1)) },
            onCancel: { result.cancelled += 1 }
        )
    }

    func testProposesTheBranchAndBaseItWasGiven() throws {
        let sut = sheet(Result())

        XCTAssertEqual(try sut.inspect().find(ViewType.TextField.self, where: {
            try $0.labelView().text().string() == "Branch"
        }).input(), "f/ABC-7-x")
        XCTAssertEqual(try sut.inspect().find(ViewType.TextField.self, where: {
            try $0.labelView().text().string() == "Base"
        }).input(), "devel")
    }

    func testCreatesNothingUntilTheCreateButtonIsPressed() throws {
        let result = Result()
        let sut = sheet(result)

        XCTAssertTrue(result.created.isEmpty)

        try sut.inspect().find(button: "Create worktree").tap()

        XCTAssertEqual(result.created.map(\.0), ["f/ABC-7-x"])
        XCTAssertEqual(result.created.map(\.1), ["devel"])
    }

    func testCancellingCreatesNothing() throws {
        let result = Result()
        let sut = sheet(result)

        try sut.inspect().find(button: "Cancel").tap()

        XCTAssertTrue(result.created.isEmpty)
        XCTAssertEqual(result.cancelled, 1)
    }

    func testRefusesABranchNameThatIsBlankOrHasSpaces() throws {
        let sut = sheet(Result(), branch: "f/ABC 7 x")

        XCTAssertTrue(try sut.inspect().find(button: "Create worktree").isDisabled())
    }

    func testCarriesTheIssueIntoItsTitle() throws {
        XCTAssertNoThrow(try sheet(Result()).inspect().find(text: "Start work on ABC-7"))
    }
}
