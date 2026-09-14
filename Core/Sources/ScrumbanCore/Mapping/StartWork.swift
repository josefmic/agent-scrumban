import Foundation

public enum StartWork {
    public static let defaultBranchTemplate = "f/<KEY>-<slug>"
    public static let maxSlugLength = 60

    public static func slug(_ summary: String) -> String {
        let folded = summary
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        guard folded.count > maxSlugLength else { return folded }

        let clipped = folded.prefix(maxSlugLength)
        guard let boundary = clipped.lastIndex(of: "-") else { return String(clipped) }
        return String(clipped[..<boundary])
    }

    public static func branch(template: String, issueKey: String, summary: String) -> String {
        template
            .replacingOccurrences(of: "<KEY>", with: issueKey)
            .replacingOccurrences(of: "<slug>", with: slug(summary))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-/ "))
    }

    public static func base(_ ref: String) -> String {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("/") ? trimmed : "origin/\(trimmed)"
    }
}
