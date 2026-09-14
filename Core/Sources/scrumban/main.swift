import Foundation
import ScrumbanCore

var truth = TruthService(runner: SystemCommandRunner())
let states = try truth.snapshot()

func marker(for activity: AgentActivity?) -> String {
    switch activity {
    case .awaitingInput: "◆"
    case .working: "●"
    case .idle: "○"
    case nil: " "
    }
}

for state in states.sorted(by: { $0.path < $1.path }) {
    let name = (state.path as NSString).lastPathComponent
    print(name)

    for session in state.sessions {
        let agent = session.pid.map { " pid=\($0)" } ?? ""
        let harness = session.harness?.rawValue ?? session.name
        let label = session.created.map { "\(harness) · \(SessionAge.label(since: $0))" } ?? harness
        print("  \(marker(for: session.activity)) \(label)\(agent)")
    }
}

let sessions = states.flatMap(\.sessions)
let live = sessions.count { $0.activity != nil }
print("\n\(live) with an agent, \(sessions.count - live) without, \(states.count) worktrees")
