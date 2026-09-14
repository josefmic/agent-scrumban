import XCTest
import os
import ScrumbanCore
@testable import AgentScrumban

private struct Route: Sendable {
    let match: String
    let body: String
    let status: Int
}

final class StubHTTP: URLProtocol {
    private static let routes = OSAllocatedUnfairLock(initialState: [Route]())
    private static let requested = OSAllocatedUnfairLock(initialState: [URL]())

    static func reset() {
        routes.withLock { $0 = [] }
        requested.withLock { $0 = [] }
    }

    static func route(_ match: String, _ body: String, status: Int = 200) {
        routes.withLock { $0.append(Route(match: match, body: body, status: status)) }
    }

    static var requestedURLs: [URL] { requested.withLock { $0 } }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubHTTP.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        Self.requested.withLock { $0.append(url) }

        let matched = Self.routes.withLock { $0.first { url.path().hasSuffix($0.match) } }
        let response = HTTPURLResponse(url: url, statusCode: matched?.status ?? 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((matched?.body ?? "{}").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class JiraFilterTests: XCTestCase {
    private let filter = "assignee = currentUser()"

    override func setUp() {
        StubHTTP.reset()
        StubHTTP.route("/board/1/sprint", #"{"values":[{"id":7,"name":"Sprint 1"}]}"#)
        StubHTTP.route("/board/1/configuration", #"{"columnConfig":{"columns":[{"name":"In Progress","statuses":[{"id":"3"}]}]}}"#)
        StubHTTP.route(
            "/sprint/7/issue",
            #"{"isLast":true,"maxResults":100,"total":1,"issues":[{"key":"ABC-7","fields":{"summary":"Seven","status":{"id":"3","name":"In Progress"}}}]}"#
        )
        StubHTTP.route("/transitions", #"{"transitions":[{"id":"31","name":"Done","to":{"id":"5"}}]}"#)
        StubHTTP.route("/board", #"{"values":[{"id":1,"name":"Board"}]}"#)
    }

    private func card() -> Card {
        Card(
            columnName: "In Progress",
            issueKey: "ABC-7",
            summary: "Seven",
            worktreePath: nil,
            branch: nil,
            diffstat: nil
        )
    }

    private func configuredModel() async -> BoardViewModel {
        let runner = RecordingRunner(outputs: ["security": "tok\n"])
        let model = BoardViewModel(runner: runner)

        await model.configureJira(
            site: URL(string: "https://example.atlassian.net")!,
            email: "a@b.cz",
            projectKey: "ABC",
            jql: filter,
            runner: runner,
            session: StubHTTP.session
        )

        return model
    }

    func testKeepsTheActiveFilterAfterATransition() async {
        let model = await configuredModel()
        let transitions = await model.loadTransitions(for: card())

        await model.apply(transitions[0], to: card())

        let issueQueries = StubHTTP.requestedURLs
            .filter { $0.path().hasSuffix("/issue") }
            .compactMap(\.query)
        XCTAssertEqual(issueQueries.count, 2)
        XCTAssertTrue(issueQueries.allSatisfy { $0.contains("assignee") })
    }

    func testLoadsTheSprintIssuesWithTheFilterOnConnect() async {
        _ = await configuredModel()

        let issueQueries = StubHTTP.requestedURLs
            .filter { $0.path().hasSuffix("/issue") }
            .compactMap(\.query)
        XCTAssertEqual(issueQueries.count, 1)
        XCTAssertTrue(issueQueries[0].contains("assignee"))
    }
}
