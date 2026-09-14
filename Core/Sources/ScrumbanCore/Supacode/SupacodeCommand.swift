import Foundation

public enum SupacodeCommand {
    public static func identifier(forPath path: String) -> String {
        let normalised = path.hasSuffix("/") ? path : path + "/"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return normalised.addingPercentEncoding(withAllowedCharacters: allowed) ?? normalised
    }

    public static func focus(worktreeId: String) -> [String] {
        ["worktree", "focus", "-w", worktreeId]
    }

    public static func focusedWorktree() -> [String] {
        ["worktree", "list", "--focused"]
    }

    public static func path(forIdentifier identifier: String) -> String? {
        guard let decoded = identifier.removingPercentEncoding, !decoded.isEmpty else { return nil }
        return decoded.count > 1 && decoded.hasSuffix("/") ? String(decoded.dropLast()) : decoded
    }

    public static func identifiers(in output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static func focused(in output: String) -> String? {
        identifiers(in: output).first
    }

    public static func surfaceIdentifier(forSession name: String) -> String? {
        let prefix = "supa-"
        guard name.hasPrefix(prefix) else { return nil }
        return String(name.dropFirst(prefix.count)).uppercased()
    }

    public static func focusSurface(worktreeId: String, tabId: String, surfaceId: String) -> [String] {
        ["surface", "focus", "-w", worktreeId, "-t", tabId, "-s", surfaceId]
    }

    public static func newWorktree(repoId: String, branch: String, base: String) -> URL? {
        var components = URLComponents()
        components.scheme = "supacode"
        components.host = "repo"
        components.percentEncodedPath = "/\(repoId)/worktree/new"
        components.percentEncodedQueryItems = [
            URLQueryItem(name: "branch", value: encoded(branch)),
            URLQueryItem(name: "base", value: encoded(base)),
            URLQueryItem(name: "fetch", value: "true"),
        ]
        return components.url
    }

    private static func encoded(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
