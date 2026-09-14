import Foundation

public struct SupacodeDriver: Sendable {
    public static let defaultExecutablePath = "/Applications/supacode.app/Contents/Resources/bin/supacode"

    private let runner: CommandRunner
    private let executablePath: String

    public init(runner: CommandRunner, executablePath: String = SupacodeDriver.defaultExecutablePath) {
        self.runner = runner
        self.executablePath = executablePath
    }

    @discardableResult
    public func run(_ arguments: [String]) throws -> String {
        try runner.run(executablePath, arguments)
    }
}
