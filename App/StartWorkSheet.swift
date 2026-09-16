import SwiftUI
import ScrumbanCore

struct StartWorkSheet: View {
    let card: Card
    let onCreate: (String, String) -> Void
    let onCancel: () -> Void

    @State private var branch: String
    @State private var base: String

    init(
        card: Card,
        branch: String,
        base: String,
        onCreate: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.card = card
        self.onCreate = onCreate
        self.onCancel = onCancel
        _branch = State(initialValue: branch)
        _base = State(initialValue: base)
    }

    private var trimmedBranch: String { branch.trimmingCharacters(in: .whitespaces) }

    private var valid: Bool {
        !trimmedBranch.isEmpty
            && trimmedBranch.rangeOfCharacter(from: .whitespaces) == nil
            && !base.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start work on \(card.issueKey ?? "")").font(.headline)
            Text(card.summary).font(.callout).foregroundStyle(.secondary)

            Form {
                TextField("Branch", text: $branch)
                    .accessibilityIdentifier("start-work-branch")
                TextField("Base", text: $base)
                    .accessibilityIdentifier("start-work-base")
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create worktree") { onCreate(trimmedBranch, base) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
