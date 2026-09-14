import Foundation

public struct RunningProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPid: Int32
    public let command: String

    public init(pid: Int32, parentPid: Int32, command: String) {
        self.pid = pid
        self.parentPid = parentPid
        self.command = command
    }
}

public enum ProcessTableParser {
    public static func parse(_ output: String) -> [RunningProcess] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let parentPid = Int32(parts[1])
            else { return nil }

            return RunningProcess(pid: pid, parentPid: parentPid, command: String(parts[2]))
        }
    }
}

public struct ProcessTree: Sendable {
    private let childrenByParent: [Int32: [RunningProcess]]

    public init(processes: [RunningProcess]) {
        childrenByParent = Dictionary(grouping: processes, by: \.parentPid)
    }

    public func descendants(of root: Int32) -> [RunningProcess] {
        var found: [RunningProcess] = []
        var pending: [Int32] = [root]

        while let next = pending.popLast() {
            for child in childrenByParent[next] ?? [] {
                found.append(child)
                pending.append(child.pid)
            }
        }

        return found
    }
}
