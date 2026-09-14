import XCTest
@testable import ScrumbanCore

final class JiraModelsTests: XCTestCase {
    func testDecodesBoardConfigurationColumns() throws {
        let json = Data("""
        {"columnConfig":{"columns":[
          {"name":"Backlog","statuses":[{"id":"10000"}]},
          {"name":"In Progress","statuses":[{"id":"3"},{"id":"10001"}]}
        ]}}
        """.utf8)

        let columns = try JSONDecoder().decode(BoardConfigurationResponse.self, from: json).columns

        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].name, "Backlog")
        XCTAssertEqual(columns[1].statusIds, ["3", "10001"])
    }

    func testDecodesIssues() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1336","fields":{"summary":"Reinstall subscription","status":{"id":"3","name":"In Progress"}}}]}
        """.utf8)

        let issues = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues

        XCTAssertEqual(issues[0].key, "ABC-1336")
        XCTAssertEqual(issues[0].summary, "Reinstall subscription")
        XCTAssertEqual(issues[0].statusId, "3")
        XCTAssertEqual(issues[0].statusName, "In Progress")
    }

    func testDecodesTheEpicOnAnIssue() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1336","fields":{"summary":"Reinstall","status":{"id":"3","name":"In Progress"},
          "epic":{"id":586168,"key":"ABC-1233","name":"Převod stávajících klientů","summary":"Převod stávajících klientů","color":{"key":"color_11"},"issueColor":{"key":"purple"},"done":false}}}]}
        """.utf8)

        let epic = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].epic

        XCTAssertEqual(epic?.label, "Převod stávajících klientů")
        XCTAssertEqual(epic?.color, "purple")
    }

    func testLabelsAnEpicWithABlankNameByItsSummary() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1336","fields":{"summary":"Reinstall","status":{"id":"3","name":"In Progress"},
          "epic":{"id":1,"key":"ABC-1158","name":"","summary":"Modul - obecné","issueColor":{"key":"purple"},"done":false}}}]}
        """.utf8)

        let epic = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].epic

        XCTAssertEqual(epic?.label, "Modul - obecné")
    }

    func testDecodesAnIssueWithoutAnEpic() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1336","fields":{"summary":"Reinstall","status":{"id":"3","name":"In Progress"}}}]}
        """.utf8)

        XCTAssertNil(try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].epic)
    }

    func testDecodesTransitions() throws {
        let json = Data("""
        {"transitions":[{"id":"31","name":"Done","to":{"id":"10002"}}]}
        """.utf8)

        let transitions = try JSONDecoder().decode(TransitionsResponse.self, from: json).transitions

        XCTAssertEqual(transitions[0].id, "31")
        XCTAssertEqual(transitions[0].toStatusId, "10002")
    }

    func testDecodesActiveSprints() throws {
        let json = Data("""
        {"values":[{"id":6638,"name":"2026-15","state":"active"}]}
        """.utf8)

        let sprints = try JSONDecoder().decode(SprintsResponse.self, from: json).values

        XCTAssertEqual(sprints.count, 1)
        XCTAssertEqual(sprints[0].id, 6638)
        XCTAssertEqual(sprints[0].name, "2026-15")
    }

    func testDecodesAnEmptySprintList() throws {
        let json = Data("{\"values\":[]}".utf8)

        XCTAssertTrue(try JSONDecoder().decode(SprintsResponse.self, from: json).values.isEmpty)
    }

    func testBuildsBasicAuthorizationHeader() {
        let credentials = JiraCredentials(
            site: URL(string: "https://example.atlassian.net")!,
            email: "a@b.cz",
            token: "secret"
        )

        XCTAssertEqual(credentials.authorizationHeader, "Basic YUBiLmN6OnNlY3JldA==")
    }

    func testDecodesTypePriorityAndStoryPoints() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1247","fields":{"summary":"SPI","status":{"id":"3","name":"In Progress"},
          "issuetype":{"name":"User story"},"priority":{"name":"Major"},"customfield_10073":5}}]}
        """.utf8)

        let issue = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0]

        XCTAssertEqual(issue.issueType, "User story")
        XCTAssertEqual(issue.priority, "Major")
        XCTAssertEqual(issue.storyPoints, 5)
    }

    func testIgnoresTheEmptyStoryPointEstimateField() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1247","fields":{"summary":"SPI","status":{"id":"3","name":"In Progress"},
          "customfield_10016":13}}]}
        """.utf8)

        XCTAssertNil(try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].storyPoints)
    }

    func testDecodesAnIssueWithoutTypePriorityOrPoints() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1247","fields":{"summary":"SPI","status":{"id":"3","name":"In Progress"}}}]}
        """.utf8)

        let issue = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0]

        XCTAssertEqual(issue.issueType, "")
        XCTAssertEqual(issue.priority, "")
        XCTAssertNil(issue.storyPoints)
        XCTAssertNil(issue.assignee)
    }

    func testDecodesTheAssigneeWithTheSmallAvatar() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1247","fields":{"summary":"SPI","status":{"id":"3","name":"In Progress"},
          "assignee":{"displayName":"Josef Michálek","avatarUrls":{"48x48":"https://a/48","24x24":"https://a/24"}}}}]}
        """.utf8)

        let assignee = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].assignee

        XCTAssertEqual(assignee?.displayName, "Josef Michálek")
        XCTAssertEqual(assignee?.avatarURL, URL(string: "https://a/24"))
    }

    func testBuildsInitialsFromTheFirstTwoNameParts() {
        XCTAssertEqual(JiraUser(displayName: "Josef Michálek", avatarURL: nil).initials, "JM")
        XCTAssertEqual(JiraUser(displayName: "Madonna", avatarURL: nil).initials, "M")
        XCTAssertEqual(JiraUser(displayName: "", avatarURL: nil).initials, "")
    }

    func testDecodesAnEpicsOwnColour() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1189","fields":{"summary":"Integrace WooCommerce","status":{"id":"1","name":"Open"},
          "issuetype":{"name":"Epic"},"customfield_10017":"dark_yellow"}}]}
        """.utf8)

        let issue = try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0]

        XCTAssertEqual(issue.issueType, "Epic")
        XCTAssertEqual(issue.epicColor, "dark_yellow")
        XCTAssertNil(issue.epic)
    }

    func testAnIssueWithoutAnEpicColourReportsNone() throws {
        let json = Data("""
        {"issues":[{"key":"ABC-1336","fields":{"summary":"Reinstall","status":{"id":"3","name":"In Progress"}}}]}
        """.utf8)

        XCTAssertEqual(try JSONDecoder().decode(IssueSearchResponse.self, from: json).issues[0].epicColor, "")
    }
}
