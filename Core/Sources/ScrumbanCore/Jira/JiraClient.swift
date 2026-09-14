import Foundation

public struct JiraClient: Sendable {
    public static let pageSize = 100
    public static let maxPages = 20
    static let fields = "summary,status,issuetype,priority,assignee,customfield_10073,customfield_10017"

    private let credentials: JiraCredentials
    private let session: URLSession

    public init(credentials: JiraCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    public func boards(projectKey: String) async throws -> [JiraBoard] {
        try await get(BoardsResponse.self, "/rest/agile/1.0/board", ["projectKeyOrId": projectKey]).values
    }

    public func columns(boardId: Int) async throws -> [JiraColumn] {
        try await get(BoardConfigurationResponse.self, "/rest/agile/1.0/board/\(boardId)/configuration", [:]).columns
    }

    public func issues(boardId: Int) async throws -> [JiraIssue] {
        try await pagedIssues(path: "/rest/agile/1.0/board/\(boardId)/issue", query: [:])
    }

    public func activeSprint(boardId: Int) async throws -> JiraSprint? {
        try await get(
            SprintsResponse.self,
            "/rest/agile/1.0/board/\(boardId)/sprint",
            ["state": "active"]
        ).values.first
    }

    public func issues(boardId: Int, sprintId: Int?, jql: String) async throws -> [JiraIssue] {
        var query: [String: String] = [:]
        if !jql.trimmingCharacters(in: .whitespaces).isEmpty {
            query["jql"] = jql
        }

        let path = sprintId.map { "/rest/agile/1.0/board/\(boardId)/sprint/\($0)/issue" }
            ?? "/rest/agile/1.0/board/\(boardId)/issue"

        let issues = try await pagedIssues(path: path, query: query)
        guard let sprintId else { return issues }

        var seen = Set(issues.map(\.key))
        let epics = try await epics(sprintId: sprintId, jql: jql)

        return issues + epics.filter { seen.insert($0.key).inserted }
    }

    private func epics(sprintId: Int, jql: String) async throws -> [JiraIssue] {
        var clause = "sprint = \(sprintId) AND issuetype = Epic"
        let filter = jql.trimmingCharacters(in: .whitespaces)
        if !filter.isEmpty { clause += " AND (\(filter))" }

        return try await get(
            IssueSearchResponse.self,
            "/rest/api/3/search/jql",
            ["jql": clause, "fields": JiraClient.fields, "maxResults": String(JiraClient.pageSize)]
        ).issues
    }

    private func pagedIssues(path: String, query: [String: String]) async throws -> [JiraIssue] {
        var collected: [JiraIssue] = []

        for _ in 0..<JiraClient.maxPages {
            var page = query
            page["fields"] = JiraClient.fields + ",epic"
            page["startAt"] = String(collected.count)
            page["maxResults"] = String(JiraClient.pageSize)

            let response = try await get(IssueSearchResponse.self, path, page)
            collected.append(contentsOf: response.issues)

            if response.isLast == true || response.issues.isEmpty { break }
            if let total = response.total, collected.count >= total { break }
            if response.issues.count < response.maxResults ?? JiraClient.pageSize { break }
        }

        return collected
    }

    public func transitions(issueKey: String) async throws -> [JiraTransition] {
        try await get(TransitionsResponse.self, "/rest/api/3/issue/\(issueKey)/transitions", [:]).transitions
    }

    public func applyTransition(issueKey: String, transitionId: String) async throws {
        var request = URLRequest(url: credentials.site.appending(path: "/rest/api/3/issue/\(issueKey)/transitions"))
        request.httpMethod = "POST"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["transition": ["id": transitionId]])

        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw JiraError.requestFailed(status: status) }
    }

    private func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String]) async throws -> T {
        var components = URLComponents(url: credentials.site.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw JiraError.requestFailed(status: status) }

        return try JSONDecoder().decode(type, from: data)
    }
}
