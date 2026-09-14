import Foundation

public struct JiraCredentials: Sendable {
    public static let keychainService = "agent-scrumban"

    public let site: URL
    public let email: String
    public let token: String

    public init(site: URL, email: String, token: String) {
        self.site = site
        self.email = email
        self.token = token
    }

    public var authorizationHeader: String {
        "Basic " + Data("\(email):\(token)".utf8).base64EncodedString()
    }

    public static func load(runner: CommandRunner, site: URL, email: String) throws -> JiraCredentials {
        let token = try token(runner: runner, email: email)

        guard !token.isEmpty else { throw JiraError.missingToken(account: email) }

        return JiraCredentials(site: site, email: email, token: token)
    }

    public static func hasStoredToken(runner: CommandRunner, email: String) -> Bool {
        guard !email.isEmpty else { return false }
        return ((try? token(runner: runner, email: email)) ?? "").isEmpty == false
    }

    public static func storeToken(runner: CommandRunner, email: String, token: String) throws {
        _ = try runner.run(
            "/usr/bin/security",
            ["add-generic-password", "-U", "-a", email, "-s", keychainService, "-w", token]
        )
    }

    public static func removeToken(runner: CommandRunner, email: String) throws {
        _ = try runner.run(
            "/usr/bin/security",
            ["delete-generic-password", "-a", email, "-s", keychainService]
        )
    }

    private static func token(runner: CommandRunner, email: String) throws -> String {
        try runner.run(
            "/usr/bin/security",
            ["find-generic-password", "-a", email, "-s", keychainService, "-w"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum JiraError: Error, Equatable {
    case missingToken(account: String)
    case requestFailed(status: Int)
    case boardNotFound(projectKey: String)
}
