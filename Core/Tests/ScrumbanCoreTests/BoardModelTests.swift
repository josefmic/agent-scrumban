import XCTest
@testable import ScrumbanCore

final class BoardModelTests: XCTestCase {
    private let columns = [
        JiraColumn(name: "Backlog", statusIds: ["10000"]),
        JiraColumn(name: "In Progress", statusIds: ["3"]),
    ]

    func testPlacesIssuesInTheColumnMatchingTheirStatus() {
        let issues = [
            JiraIssue(key: "ABC-1", summary: "One", statusId: "10000", statusName: "Backlog"),
            JiraIssue(key: "ABC-2", summary: "Two", statusId: "3", statusName: "In Progress"),
        ]

        let lanes = BoardModel.build(columns: columns, issues: issues, worktrees: [], branches: [:])

        XCTAssertEqual(lanes.map(\.name), ["Backlog", "In Progress"])
        XCTAssertEqual(lanes[0].cards.map(\.issueKey), ["ABC-1"])
        XCTAssertEqual(lanes[1].cards.map(\.issueKey), ["ABC-2"])
    }

    func testAttachesWorktreeAndAgentActivityToItsIssue() {
        let issues = [JiraIssue(key: "ABC-2", summary: "Two", statusId: "3", statusName: "In Progress")]
        let worktrees = [WorktreeState(path: "/w/two", sessions: [AgentSession(name: "supa-a", pid: 99, harness: .claude, activity: .working)])]

        let lanes = BoardModel.build(
            columns: columns,
            issues: issues,
            worktrees: worktrees,
            branches: ["/w/two": "f/ABC-2-two"]
        )

        let card = lanes[1].cards[0]
        XCTAssertEqual(card.worktreePath, "/w/two")
        XCTAssertEqual(card.sessions.map(\.name), ["supa-a"])
        XCTAssertEqual(card.sessions.first?.activity, .working)
        XCTAssertEqual(card.branch, "f/ABC-2-two")
    }

    func testIssueWithoutWorktreeHasNoAgent() {
        let issues = [JiraIssue(key: "ABC-1", summary: "One", statusId: "10000", statusName: "Backlog")]

        let card = BoardModel.build(columns: columns, issues: issues, worktrees: [], branches: [:])[0].cards[0]

        XCTAssertNil(card.worktreePath)
        XCTAssertTrue(card.sessions.isEmpty)
    }

    func testAWorktreeWithNoSessionStillCarriesItsBranchOntoTheCard() {
        let issues = [JiraIssue(key: "ABC-639", summary: "DPD SK", statusId: "3", statusName: "In Progress")]
        let worktrees = [WorktreeState(path: "/w/639", sessions: [])]

        let lanes = BoardModel.build(
            columns: columns,
            issues: issues,
            worktrees: worktrees,
            branches: ["/w/639": "f/ABC-639-dpd-sk-carrier"]
        )

        let card = lanes[1].cards[0]

        XCTAssertEqual(card.worktreePath, "/w/639")
        XCTAssertEqual(card.branch, "f/ABC-639-dpd-sk-carrier")
        XCTAssertTrue(card.sessions.isEmpty)
    }

    func testAWorktreeWithNoIssueKeyStaysOffTheBoard() {
        let worktrees = [WorktreeState(path: "/w/sb", sessions: [AgentSession(name: "supa-b")])]

        let lanes = BoardModel.build(
            columns: columns,
            issues: [],
            worktrees: worktrees,
            branches: ["/w/sb": "f/storybook-deploy"]
        )

        XCTAssertEqual(lanes.map(\.name), ["Backlog", "In Progress"])
        XCTAssertTrue(lanes.allSatisfy { $0.cards.isEmpty })
    }

    func testTheBoardHoldsNothingButJiraColumns() {
        let lanes = BoardModel.build(columns: columns, issues: [], worktrees: [], branches: [:])

        XCTAssertEqual(lanes.map(\.name), ["Backlog", "In Progress"])
    }

    func testIssueWithStatusOutsideEveryColumnContributesNoCard() {
        let issues = [JiraIssue(key: "ABC-9", summary: "Nine", statusId: "99999", statusName: "Elsewhere")]
        let worktrees = [WorktreeState(path: "/w/nine", sessions: [AgentSession(name: "supa-n", pid: 33, harness: .claude, activity: .awaitingInput)])]

        let lanes = BoardModel.build(
            columns: columns,
            issues: issues,
            worktrees: worktrees,
            branches: ["/w/nine": "f/ABC-9-x"]
        )

        XCTAssertTrue(lanes.allSatisfy { $0.cards.isEmpty })
    }

    func testTheFirstWorktreeOnAnIssueKeyTakesItsCard() {
        let issues = [JiraIssue(key: "ABC-7", summary: "Seven", statusId: "3", statusName: "In Progress")]
        let worktrees = [
            WorktreeState(path: "/w/first", sessions: [AgentSession(name: "supa-a", pid: 11)]),
            WorktreeState(path: "/w/second", sessions: [AgentSession(name: "supa-b")]),
        ]

        let lanes = BoardModel.build(
            columns: columns,
            issues: issues,
            worktrees: worktrees,
            branches: ["/w/first": "f/ABC-7-first", "/w/second": "f/ABC-7-second"]
        )

        XCTAssertEqual(lanes[1].cards.map { $0.sessions.first?.name }, ["supa-a"])
        XCTAssertEqual(lanes[1].cards.map(\.worktreePath), ["/w/first"])
    }

    func testTheSameIssueInTwoColumnsProducesDistinctCardIdentities() {
        let mirrored = [
            JiraColumn(name: "Doing", statusIds: ["3"]),
            JiraColumn(name: "Review", statusIds: ["3"]),
        ]
        let issues = [JiraIssue(key: "ABC-5", summary: "Five", statusId: "3", statusName: "In Progress")]

        let lanes = BoardModel.build(columns: mirrored, issues: issues, worktrees: [], branches: [:])

        XCTAssertNotEqual(lanes[0].cards[0].id, lanes[1].cards[0].id)
    }

    func testCountsTheColumnTotalBeforeTheFilterNarrowedIt() {
        let visible = [JiraIssue(key: "ABC-1", summary: "One", statusId: "10000", statusName: "Backlog")]
        let everything = visible + [
            JiraIssue(key: "ABC-8", summary: "Eight", statusId: "10000", statusName: "Backlog"),
            JiraIssue(key: "ABC-9", summary: "Nine", statusId: "3", statusName: "In Progress"),
        ]

        let lanes = BoardModel.build(
            columns: columns,
            issues: visible,
            allIssues: everything,
            worktrees: [],
            branches: [:]
        )

        XCTAssertEqual(lanes[0].cards.count, 1)
        XCTAssertEqual(lanes[0].total, 2)
        XCTAssertEqual(lanes[1].total, 1)
    }

    func testTotalMatchesTheCardCountWhenNothingIsFilteredOut() {
        let issues = [JiraIssue(key: "ABC-1", summary: "One", statusId: "10000", statusName: "Backlog")]

        let lanes = BoardModel.build(columns: columns, issues: issues, worktrees: [], branches: [:])

        XCTAssertEqual(lanes[0].total, 1)
        XCTAssertEqual(lanes[1].total, 0)
    }

    func testCarriesTheHarnessOntoTheCard() {
        let issues = [JiraIssue(key: "ABC-2", summary: "Two", statusId: "3", statusName: "In Progress")]
        let worktrees = [WorktreeState(path: "/w/two", sessions: [AgentSession(name: "supa-a", pid: 99, harness: .codex, activity: .idle)])]

        let lanes = BoardModel.build(
            columns: columns,
            issues: issues,
            worktrees: worktrees,
            branches: ["/w/two": "f/ABC-2-two"]
        )

        XCTAssertEqual(lanes[1].cards[0].sessions.first?.harness, .codex)
    }
}
