import XCTest
import SwiftUI
import ViewInspector
import ScrumbanCore
@testable import AgentScrumban

final class CardViewTests: XCTestCase {
    private func card(
        key: String? = "ABC-7",
        epic: JiraEpic? = JiraEpic(key: "ABC-1233", name: "Převod klientů", summary: "Převod klientů", color: "purple"),
        issueType: String = "User story",
        priority: String = "Major",
        storyPoints: Double? = 5,
        assignee: JiraUser? = JiraUser(displayName: "Josef Michálek", avatarURL: nil),
        epicColor: String = "",
        summary: String = "Reinstall subscription",
        worktreePath: String? = "/w/one",
        agent: AgentActivity? = .working,
        harness: AgentKind? = .claude,
        branch: String? = "f/ABC-7-thing",
        diffstat: DiffStat? = DiffStat(added: 82, removed: 14),
        sessions: [AgentSession]? = nil
    ) -> Card {
        Card(
            columnName: "In Progress",
            issueKey: key,
            summary: summary,
            epic: epic,
            issueType: issueType,
            priority: priority,
            storyPoints: storyPoints,
            assignee: assignee,
            epicColor: epicColor,
            worktreePath: worktreePath,
            sessions: sessions ?? agent.map {
                [AgentSession(name: "supa-a", pid: 200, harness: harness, activity: $0)]
            } ?? [],
            branch: branch,
            diffstat: diffstat
        )
    }

    private func view(_ card: Card) -> CardView {
        CardView(card: card, onOpen: {}, onFocusSession: { _ in }, onStartWork: {}, onMove: {})
    }

    private final class Clicks: @unchecked Sendable {
        var opened = 0
        var started = 0
        var focused = 0
    }

    private func tap(_ card: Card) throws -> Clicks {
        let clicks = Clicks()
        let sut = CardView(
            card: card,
            onOpen: { clicks.opened += 1 },
            onFocusSession: { _ in clicks.focused += 1 },
            onStartWork: { clicks.started += 1 },
            onMove: {}
        )

        try sut.inspect().vStack().callOnTapGesture()

        return clicks
    }

    func testClickingAnIssueWithAWorktreeOpensIt() throws {
        let clicks = try tap(card())

        XCTAssertEqual(clicks.opened, 1)
        XCTAssertEqual(clicks.started, 0)
    }

    func testClickingAnUntouchedIssueAsksToStartWork() throws {
        let clicks = try tap(card(worktreePath: nil, agent: nil, harness: nil, branch: nil, diffstat: nil))

        XCTAssertEqual(clicks.opened, 0)
        XCTAssertEqual(clicks.started, 1)
    }

    func testClickingACardWithNoIssueKeyAndNoWorktreeDoesNothing() throws {
        let clicks = try tap(card(key: nil, worktreePath: nil, agent: nil, harness: nil, branch: nil, diffstat: nil))

        XCTAssertEqual(clicks.opened, 0)
        XCTAssertEqual(clicks.started, 0)
    }

    private func session(
        _ name: String,
        activity: AgentActivity = .working,
        minutesOld: Double = 14
    ) -> AgentSession {
        AgentSession(
            name: name,
            pid: 200,
            harness: .claude,
            activity: activity,
            created: Date(timeIntervalSinceNow: -minutesOld * 60)
        )
    }

    func testGivesEachSessionOfASharedWorktreeItsOwnRow() throws {
        let sut = view(card(sessions: [
            session("supa-1554ecd5-8d15-412a-8345-5bcbd840fb81", minutesOld: 14),
            session("supa-cc376a89-4c13-4a62-9a9f-136d7dd3c9cf", activity: .awaitingInput, minutesOld: 120),
        ]))

        XCTAssertNoThrow(try sut.inspect().find(text: "Claude · 14m"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Claude · 2h"))
    }

    func testLabelsASessionWithoutAStartTimeByItsHarnessAlone() throws {
        let sut = view(card(sessions: [
            AgentSession(name: "supa-1554ecd5", pid: 200, harness: .claude, activity: .working),
        ]))

        XCTAssertNoThrow(try sut.inspect().find(text: "Claude"))
    }

    func testGivesALoneSessionItsOwnRowToo() throws {
        let sut = view(card(sessions: [session("supa-1554ecd5")]))

        XCTAssertNoThrow(try sut.inspect().find(ViewType.Button.self))
        XCTAssertNoThrow(try sut.inspect().find(text: "Claude · 14m"))
    }

    func testClickingASessionRowFocusesThatSession() throws {
        let clicks = Clicks()
        let sessions = [
            session("supa-1554ecd5-8d15-412a-8345-5bcbd840fb81", minutesOld: 14),
            session("supa-cc376a89-4c13-4a62-9a9f-136d7dd3c9cf", minutesOld: 120),
        ]
        let sut = CardView(
            card: card(sessions: sessions),
            onOpen: { clicks.opened += 1 },
            onFocusSession: { _ in clicks.focused += 1 },
            onStartWork: { clicks.started += 1 },
            onMove: {}
        )

        try sut.inspect()
            .find(ViewType.Button.self, containing: "Claude · 2h")
            .tap()

        XCTAssertEqual(clicks.focused, 1)
        XCTAssertEqual(clicks.opened, 0)
    }

    func testDimsAnIssueWithNothingBehindIt() throws {
        let sut = view(card(worktreePath: nil, agent: nil, harness: nil, branch: nil, diffstat: nil))

        XCTAssertLessThan(try sut.inspect().vStack().opacity(), 1)
    }

    func testLeavesAWorktreeBackedCardAtFullStrength() throws {
        let sut = view(card())

        XCTAssertEqual(try sut.inspect().vStack().opacity(), 1)
    }

    func testShowsTheIssueKeyAndSummary() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(text: "ABC-7"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Reinstall subscription"))
    }

    func testShowsTheBranch() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(text: "f/ABC-7-thing"))
    }

    func testShowsTheDiffstat() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(text: "+82"))
        XCTAssertNoThrow(try sut.inspect().find(text: "−14"))
    }

    func testHidesTheDiffstatWhenThereAreNoChanges() throws {
        let sut = view(card(diffstat: DiffStat(added: 0, removed: 0)))

        XCTAssertThrowsError(try sut.inspect().find(text: "+0"))
    }

    func testShowsTheEpic() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(text: "Převod klientů"))
    }

    func testShowsNoEpicChipWhenTheIssueHasNone() throws {
        let sut = view(card(epic: nil))

        XCTAssertThrowsError(try sut.inspect().find(EpicChip.self))
    }

    func testSpellsOutAWorkingSession() throws {
        let sut = view(card(agent: .working))

        XCTAssertNoThrow(try sut.inspect().find(text: "working"))
    }

    func testSpellsOutAnIdleSession() throws {
        let sut = view(card(agent: .idle))

        XCTAssertNoThrow(try sut.inspect().find(text: "idle"))
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Image.self, where: {
            try $0.actualImage().name() == "moon.zzz.fill"
        }))
    }

    func testCallsOutASessionThatIsWaitingForTheUser() throws {
        let sut = view(card(agent: .awaitingInput))

        XCTAssertNoThrow(try sut.inspect().find(text: "waiting for you"))
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Image.self, where: {
            try $0.actualImage().name() == "bell.badge.fill"
        }))
    }

    func testShowsNothingAtAllWhenNoAgentSessionIsOpen() throws {
        let sut = view(card(agent: nil))

        XCTAssertThrowsError(try sut.inspect().find(HarnessBadge.self))
        XCTAssertThrowsError(try sut.inspect().find(ViewType.Button.self))
    }

    func testOmitsTheIssueKeyForAnUnmappedCard() throws {
        let sut = view(card(key: nil))

        XCTAssertThrowsError(try sut.inspect().find(text: "ABC-7"))
    }

    func testShowsWholeStoryPointsWithoutADecimal() throws {
        let sut = view(card(storyPoints: 5))

        XCTAssertNoThrow(try sut.inspect().find(text: "5"))
    }

    func testShowsNoStoryPointsWhenTheIssueHasNone() throws {
        let sut = view(card(storyPoints: nil))

        XCTAssertThrowsError(try sut.inspect().find(text: "5"))
    }

    func testShowsTheIssueTypeAndPriorityIcons() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(IssueTypeIcon.self))
        XCTAssertNoThrow(try sut.inspect().find(PriorityIcon.self))
    }

    func testOmitsTheTypeAndPriorityIconsWhenJiraSentNeither() throws {
        let sut = view(card(issueType: "", priority: ""))

        XCTAssertThrowsError(try sut.inspect().find(IssueTypeIcon.self))
        XCTAssertThrowsError(try sut.inspect().find(PriorityIcon.self))
    }

    func testShowsTheAssigneeAvatar() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(AssigneeAvatar.self))
    }

    func testOmitsTheAvatarForAnUnassignedIssue() throws {
        let sut = view(card(assignee: nil))

        XCTAssertThrowsError(try sut.inspect().find(AssigneeAvatar.self))
    }

    func testSeparatesOurOwnRowsWithADivider() throws {
        let sut = view(card())

        XCTAssertNoThrow(try sut.inspect().find(ViewType.Divider.self))
    }

    func testShowsNeitherDividerNorGitRowsForAnUnstartedIssue() throws {
        let sut = view(card(agent: nil, harness: nil, branch: nil, diffstat: nil))

        XCTAssertThrowsError(try sut.inspect().find(ViewType.Divider.self))
        XCTAssertThrowsError(try sut.inspect().find(HarnessBadge.self))
    }

    func testAnEpicCardWearsItsOwnChip() throws {
        let sut = view(card(
            key: "ABC-1189",
            epic: nil,
            issueType: "Epic",
            epicColor: "dark_yellow",
            summary: "Integrace WooCommerce"
        ))

        let chip = try sut.inspect().find(EpicChip.self).actualView()

        XCTAssertEqual(chip.epic.key, "ABC-1189")
        XCTAssertEqual(chip.epic.label, "Integrace WooCommerce")
        XCTAssertEqual(chip.epic.color, "dark_yellow")
    }

    func testAChildIssueKeepsItsParentEpicChip() throws {
        let sut = view(card())

        let chip = try sut.inspect().find(EpicChip.self).actualView()

        XCTAssertEqual(chip.epic.key, "ABC-1233")
    }

    func testANonEpicIssueWithoutAParentStillShowsNoChip() throws {
        let sut = view(card(epic: nil, issueType: "Bug"))

        XCTAssertThrowsError(try sut.inspect().find(EpicChip.self))
    }
}
