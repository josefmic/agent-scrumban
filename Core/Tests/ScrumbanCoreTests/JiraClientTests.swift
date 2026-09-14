import XCTest
@testable import ScrumbanCore

final class JiraClientTests: XCTestCase {
    private func client() -> JiraClient {
        JiraClient(
            credentials: JiraCredentials(site: URL(string: "https://example.atlassian.net")!, email: "a@b.cz", token: "tok"),
            session: StubURLProtocol.session
        )
    }

    private func page(total: Int, maxResults: Int, keys: [String]) -> String {
        let issues = keys.map {
            "{\"key\":\"\($0)\",\"fields\":{\"summary\":\"s\",\"status\":{\"id\":\"3\",\"name\":\"In Progress\"}}}"
        }
        return "{\"maxResults\":\(maxResults),\"total\":\(total),\"issues\":[\(issues.joined(separator: ","))]}"
    }

    private func epicPage(_ keys: [String]) -> String {
        let issues = keys.map {
            "{\"key\":\"\($0)\",\"fields\":{\"summary\":\"e\",\"status\":{\"id\":\"3\",\"name\":\"In Progress\"},\"issuetype\":{\"name\":\"Epic\"}}}"
        }
        return "{\"isLast\":true,\"issues\":[\(issues.joined(separator: ","))]}"
    }

    override func setUp() {
        StubURLProtocol.reset()
    }

    func testCollectsEveryPageOfASprint() async throws {
        StubURLProtocol.enqueue(page(total: 3, maxResults: 2, keys: ["ABC-1", "ABC-2"]))
        StubURLProtocol.enqueue(page(total: 3, maxResults: 2, keys: ["ABC-3"]))
        StubURLProtocol.enqueue(epicPage([]))

        let issues = try await client().issues(boardId: 1, sprintId: 7, jql: "")

        XCTAssertEqual(issues.map(\.key), ["ABC-1", "ABC-2", "ABC-3"])
        let queries = StubURLProtocol.requestedURLs.compactMap(\.query)
        XCTAssertTrue(queries.contains { $0.contains("startAt=0") })
        XCTAssertTrue(queries.contains { $0.contains("startAt=2") })
    }

    func testStopsWhenAPageReportsItIsTheLast() async throws {
        StubURLProtocol.enqueue("{\"isLast\":true,\"maxResults\":50,\"issues\":[]}")

        let issues = try await client().issues(boardId: 1)

        XCTAssertEqual(issues.count, 0)
        XCTAssertEqual(StubURLProtocol.requestedURLs.count, 1)
    }

    func testStopsPagingWhenTheServerKeepsRepeatingAFullPage() async throws {
        StubURLProtocol.enqueue(page(total: 9_999, maxResults: 1, keys: ["ABC-1"]))

        let issues = try await client().issues(boardId: 1, sprintId: nil, jql: "")

        XCTAssertEqual(StubURLProtocol.requestedURLs.count, JiraClient.maxPages)
        XCTAssertEqual(issues.count, JiraClient.maxPages)
    }

    func testAsksForTheStoryPointsFieldByItsRealIdentifier() async throws {
        StubURLProtocol.enqueue(page(total: 0, maxResults: 50, keys: []))

        _ = try await client().issues(boardId: 1)

        let query = StubURLProtocol.requestedURLs[0].query?.removingPercentEncoding ?? ""
        XCTAssertTrue(query.contains("customfield_10073"))
        XCTAssertFalse(query.contains("customfield_10016"))
    }

    func testMergesTheSprintEpicsTheAgileEndpointOmits() async throws {
        StubURLProtocol.enqueue(page(total: 1, maxResults: 50, keys: ["ABC-1"]))
        StubURLProtocol.enqueue(epicPage(["ABC-1233", "ABC-1189"]))

        let issues = try await client().issues(boardId: 1, sprintId: 6638, jql: "")

        XCTAssertEqual(issues.map(\.key), ["ABC-1", "ABC-1233", "ABC-1189"])
        XCTAssertEqual(StubURLProtocol.requestedURLs.last?.path, "/rest/api/3/search/jql")
        let epicQuery = StubURLProtocol.requestedURLs.last?.query?.removingPercentEncoding ?? ""
        XCTAssertTrue(epicQuery.contains("sprint = 6638 AND issuetype = Epic"))
    }

    func testNarrowsTheEpicSearchWithTheConfiguredFilter() async throws {
        StubURLProtocol.enqueue(page(total: 0, maxResults: 50, keys: []))
        StubURLProtocol.enqueue(epicPage([]))

        _ = try await client().issues(boardId: 1, sprintId: 6638, jql: "assignee = currentUser()")

        let epicQuery = StubURLProtocol.requestedURLs.last?.query?.removingPercentEncoding ?? ""
        XCTAssertTrue(epicQuery.contains("AND (assignee = currentUser())"))
    }

    func testKeepsOneCardWhenAnEpicComesBackFromBothCalls() async throws {
        StubURLProtocol.enqueue(page(total: 1, maxResults: 50, keys: ["ABC-1233"]))
        StubURLProtocol.enqueue(epicPage(["ABC-1233"]))

        let issues = try await client().issues(boardId: 1, sprintId: 6638, jql: "")

        XCTAssertEqual(issues.map(\.key), ["ABC-1233"])
    }

    func testDoesNotSearchForEpicsWithoutAnActiveSprint() async throws {
        StubURLProtocol.enqueue(page(total: 0, maxResults: 50, keys: []))

        _ = try await client().issues(boardId: 1, sprintId: nil, jql: "")

        XCTAssertEqual(StubURLProtocol.requestedURLs.count, 1)
    }
}
