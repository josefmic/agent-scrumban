import Foundation
import os
@testable import ScrumbanCore

struct Call: Equatable {
    let executable: String
    let arguments: [String]
}

final class RecordingRunner: CommandRunner {
    private let recorded = OSAllocatedUnfairLock(initialState: [Call]())
    private let outputs: [[String]: String]

    init(outputs: [[String]: String] = [:]) {
        self.outputs = outputs
    }

    var calls: [Call] { recorded.withLock { $0 } }

    func run(_ executable: String, _ arguments: [String]) throws -> String {
        recorded.withLock { $0.append(Call(executable: executable, arguments: arguments)) }
        return outputs[arguments] ?? ""
    }
}
