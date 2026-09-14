import SwiftUI
import ScrumbanCore

struct SessionRow: View {
    let session: AgentSession
    let onFocus: () -> Void

    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 4) }

    private var label: String {
        let name = session.harness?.rawValue.capitalized
            ?? String(SupacodeCommand.surfaceIdentifier(forSession: session.name)?.prefix(8) ?? "")
        guard let created = session.created else { return name }
        return "\(name) · \(SessionAge.label(since: created))"
    }

    private var fill: AnyShapeStyle {
        if session.activity == .awaitingInput {
            return AnyShapeStyle(Color.orange.opacity(hovering ? 0.45 : 0.3))
        }
        return hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)
    }

    var body: some View {
        Button(action: onFocus) {
            HarnessBadge(harness: session.harness, activity: session.activity ?? .idle, label: label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(fill, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(HarnessBadge.label(for: session.activity ?? .idle))")
        .onHover { hovering = $0 }
    }
}
