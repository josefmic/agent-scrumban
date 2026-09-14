import SwiftUI
import ScrumbanCore

struct TransitionSheet: View {
    let card: Card
    let transitions: [JiraTransition]
    let onApply: (JiraTransition) -> Void
    let onCancel: () -> Void

    @State private var selection: JiraTransition?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move \(card.issueKey ?? "")").font(.headline)
            Text(card.summary).font(.callout).foregroundStyle(.secondary)

            Picker("Transition", selection: $selection) {
                Text("Choose…").tag(JiraTransition?.none)
                ForEach(transitions, id: \.id) { transition in
                    Text(transition.name).tag(JiraTransition?.some(transition))
                }
            }
            .labelsHidden()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Apply") { if let selection { onApply(selection) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
