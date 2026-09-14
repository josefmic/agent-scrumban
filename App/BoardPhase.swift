import Foundation
import ScrumbanCore

enum SetupField: Equatable {
    case site
    case email
    case projectKey
    case token

    var label: String {
        switch self {
        case .site: "Site"
        case .email: "Email"
        case .projectKey: "Project key"
        case .token: "API token"
        }
    }
}

struct JiraSetup: Equatable {
    let site: String
    let email: String
    let projectKey: String
    let hasToken: Bool

    var url: URL? {
        let trimmed = site.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.host() != nil else { return nil }
        return url
    }

    var missing: [SetupField] {
        var fields: [SetupField] = []
        if url == nil { fields.append(.site) }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append(.email) }
        if projectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append(.projectKey) }
        if !hasToken { fields.append(.token) }
        return fields
    }

    var isComplete: Bool { missing.isEmpty }
}

enum EmptyBoard: Equatable {
    case noColumns
    case noIssues
    case hiddenByFilter
    case noWorktrees
}

enum BoardPhase: Equatable {
    case setup([SetupField])
    case loading
    case failed(String)
    case empty(EmptyBoard)
    case board

    static func of(
        setup: JiraSetup,
        loaded: Bool,
        error: String?,
        columns: [BoardColumnModel],
        worktrees: Int
    ) -> BoardPhase {
        let missing = setup.missing
        guard missing.isEmpty else { return .setup(missing) }

        guard columns.isEmpty else {
            let cards = columns.reduce(0) { $0 + $1.cards.count }
            if cards > 0 { return .board }
            if columns.reduce(0, { $0 + $1.total }) > 0 { return .empty(.hiddenByFilter) }
            return .empty(worktrees == 0 ? .noWorktrees : .noIssues)
        }

        if let error { return .failed(error) }
        return loaded ? .empty(.noColumns) : .loading
    }
}
