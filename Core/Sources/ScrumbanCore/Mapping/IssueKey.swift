import Foundation

public enum IssueKey {
    private static var pattern: Regex<Substring> { /[A-Z][A-Z0-9]+-[0-9]+/ }

    public static func extract(fromBranch branch: String) -> String? {
        branch.firstMatch(of: pattern).map { String($0.output) }
    }
}
