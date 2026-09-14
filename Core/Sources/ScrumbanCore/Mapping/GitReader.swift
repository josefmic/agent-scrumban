import Foundation

public struct DiffStat: Equatable, Sendable {
    public let added: Int
    public let removed: Int

    public init(added: Int, removed: Int) {
        self.added = added
        self.removed = removed
    }
}

public struct GitReader: Sendable {
    public static let defaultBaseBranch = "main"

    private let runner: CommandRunner

    public init(runner: CommandRunner) {
        self.runner = runner
    }

    public func branch(at path: String) -> String? {
        guard let output = try? runner.run("/usr/bin/git", ["-C", path, "branch", "--show-current"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        return output.isEmpty ? nil : output
    }

    public func diffstat(at path: String, baseBranch: String = GitReader.defaultBaseBranch) -> DiffStat {
        let forkPoint = try? runner.run("/usr/bin/git", ["-C", path, "merge-base", "HEAD", baseBranch])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let range = forkPoint.flatMap { $0.isEmpty ? nil : $0 } ?? "HEAD"

        guard let output = try? runner.run("/usr/bin/git", ["-C", path, "diff", "--shortstat", range])
        else { return DiffStat(added: 0, removed: 0) }

        return DiffStat(
            added: number(before: "insertion", in: output),
            removed: number(before: "deletion", in: output)
        )
    }

    private func number(before word: String, in output: String) -> Int {
        guard let range = output.range(of: word) else { return 0 }
        let digits = output[..<range.lowerBound]
            .reversed()
            .drop { !$0.isNumber }
            .prefix { $0.isNumber }
            .reversed()
        return Int(String(digits)) ?? 0
    }
}
