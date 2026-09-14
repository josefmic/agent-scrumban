import Foundation

public struct JiraBoard: Equatable, Sendable, Decodable {
    public let id: Int
    public let name: String
}

public struct JiraColumn: Equatable, Sendable {
    public let name: String
    public let statusIds: [String]

    public init(name: String, statusIds: [String]) {
        self.name = name
        self.statusIds = statusIds
    }
}

public struct JiraEpic: Equatable, Sendable, Decodable {
    public let key: String
    public let name: String
    public let summary: String
    public let color: String

    public init(key: String, name: String, summary: String, color: String) {
        self.key = key
        self.name = name
        self.summary = summary
        self.color = color
    }

    public var label: String {
        if !name.isEmpty { return name }
        if !summary.isEmpty { return summary }
        return key
    }

    private struct Swatch: Decodable { let key: String }

    private enum CodingKeys: String, CodingKey { case key, name, summary, issueColor }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        color = try container.decodeIfPresent(Swatch.self, forKey: .issueColor)?.key ?? ""
    }
}

public struct JiraUser: Equatable, Sendable, Decodable {
    public let displayName: String
    public let avatarURL: URL?

    public init(displayName: String, avatarURL: URL?) {
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    public var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }

    private enum CodingKeys: String, CodingKey { case displayName, avatarUrls }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarURL = try container.decodeIfPresent([String: String].self, forKey: .avatarUrls)?["24x24"]
            .flatMap { URL(string: $0) }
    }
}

public struct JiraIssue: Equatable, Sendable {
    public let key: String
    public let summary: String
    public let statusId: String
    public let statusName: String
    public let epic: JiraEpic?
    public let issueType: String
    public let priority: String
    public let storyPoints: Double?
    public let assignee: JiraUser?
    public let epicColor: String

    public init(
        key: String,
        summary: String,
        statusId: String,
        statusName: String,
        epic: JiraEpic? = nil,
        issueType: String = "",
        priority: String = "",
        storyPoints: Double? = nil,
        assignee: JiraUser? = nil,
        epicColor: String = ""
    ) {
        self.key = key
        self.summary = summary
        self.statusId = statusId
        self.statusName = statusName
        self.epic = epic
        self.issueType = issueType
        self.priority = priority
        self.storyPoints = storyPoints
        self.assignee = assignee
        self.epicColor = epicColor
    }
}

public struct JiraTransition: Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let toStatusId: String
}

public struct JiraSprint: Equatable, Sendable, Decodable {
    public let id: Int
    public let name: String
}

struct SprintsResponse: Decodable {
    let values: [JiraSprint]
}

struct BoardsResponse: Decodable {
    let values: [JiraBoard]
}

struct BoardConfigurationResponse: Decodable {
    let columns: [JiraColumn]

    private struct ColumnConfig: Decodable {
        struct Column: Decodable {
            struct Status: Decodable { let id: String }
            let name: String
            let statuses: [Status]
        }
        let columns: [Column]
    }

    private enum CodingKeys: String, CodingKey { case columnConfig }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let config = try container.decode(ColumnConfig.self, forKey: .columnConfig)
        columns = config.columns.map { JiraColumn(name: $0.name, statusIds: $0.statuses.map(\.id)) }
    }
}

struct IssueSearchResponse: Decodable {
    let issues: [JiraIssue]
    let total: Int?
    let maxResults: Int?
    let isLast: Bool?

    private struct RawIssue: Decodable {
        struct Fields: Decodable {
            struct Status: Decodable { let id: String; let name: String }
            struct Named: Decodable { let name: String }

            let summary: String
            let status: Status
            let epic: JiraEpic?
            let issuetype: Named?
            let priority: Named?
            let assignee: JiraUser?
            let storyPoints: Double?
            let epicColor: String?

            enum CodingKeys: String, CodingKey {
                case summary, status, epic, issuetype, priority, assignee
                case storyPoints = "customfield_10073"
                case epicColor = "customfield_10017"
            }
        }
        let key: String
        let fields: Fields
    }

    private enum CodingKeys: String, CodingKey { case issues, total, maxResults, isLast }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        maxResults = try container.decodeIfPresent(Int.self, forKey: .maxResults)
        isLast = try container.decodeIfPresent(Bool.self, forKey: .isLast)
        issues = try container.decode([RawIssue].self, forKey: .issues).map {
            JiraIssue(
                key: $0.key,
                summary: $0.fields.summary,
                statusId: $0.fields.status.id,
                statusName: $0.fields.status.name,
                epic: $0.fields.epic,
                issueType: $0.fields.issuetype?.name ?? "",
                priority: $0.fields.priority?.name ?? "",
                storyPoints: $0.fields.storyPoints,
                assignee: $0.fields.assignee,
                epicColor: $0.fields.epicColor ?? ""
            )
        }
    }
}

struct TransitionsResponse: Decodable {
    let transitions: [JiraTransition]

    private struct RawTransition: Decodable {
        struct To: Decodable { let id: String }
        let id: String
        let name: String
        let to: To
    }

    private enum CodingKeys: String, CodingKey { case transitions }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transitions = try container.decode([RawTransition].self, forKey: .transitions).map {
            JiraTransition(id: $0.id, name: $0.name, toStatusId: $0.to.id)
        }
    }
}
