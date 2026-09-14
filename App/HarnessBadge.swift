import SwiftUI
import ScrumbanCore

struct HarnessBadge: View {
    let harness: AgentKind?
    let activity: AgentActivity
    var label: String?

    static func symbol(for harness: AgentKind?) -> String {
        switch harness {
        case .claude: "sparkles"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .copilot: "airplane"
        case .aider: "hammer"
        case .opencode: "curlybraces"
        case .gemini: "circle.hexagongrid"
        case nil: "moon.zzz"
        }
    }

    static func label(for activity: AgentActivity) -> String {
        switch activity {
        case .working: "working"
        case .awaitingInput: "waiting for you"
        case .idle: "idle"
        }
    }

    private var help: String {
        guard let label else { return Self.label(for: activity) }
        return "\(label) — \(Self.label(for: activity))"
    }

    private var indicator: String {
        switch activity {
        case .working: "arrow.triangle.2.circlepath"
        case .awaitingInput: "bell.badge.fill"
        case .idle: "moon.zzz.fill"
        }
    }

    private var tint: Color {
        switch activity {
        case .working: .green
        case .awaitingInput: .orange
        case .idle: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: Self.symbol(for: harness))

            if let label {
                Text(label).lineLimit(1).truncationMode(.tail)
            }

            Spacer(minLength: 4)

            Image(systemName: indicator)
            Text(Self.label(for: activity)).layoutPriority(1)
        }
        .font(activity == .awaitingInput ? .caption.bold() : .caption2)
        .foregroundStyle(tint)
        .help(help)
    }
}
