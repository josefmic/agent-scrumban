import Foundation

public enum CommandError: Error, Equatable {
    case failed(executable: String, arguments: [String], status: Int32, standardError: String)
}

extension CommandError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .failed(executable, arguments, status, standardError):
            let command = ([(executable as NSString).lastPathComponent] + arguments).joined(separator: " ")
            let detail = standardError.isEmpty ? "exited \(status)" : standardError
            return "\(command): \(detail)"
        }
    }
}

public protocol CommandRunner: Sendable {
    func run(_ executable: String, _ arguments: [String]) throws -> String
}

public struct SystemCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        exited.wait()

        guard process.terminationStatus == 0 else {
            throw CommandError.failed(
                executable: executable,
                arguments: arguments,
                status: process.terminationStatus,
                standardError: String(decoding: errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return String(decoding: outputData, as: UTF8.self)
    }
}
