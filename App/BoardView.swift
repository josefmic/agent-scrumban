import SwiftUI
import ScrumbanCore

struct BoardView: View {
    @ObservedObject var model: BoardViewModel

    @AppStorage(SettingsKey.repositoryPath) private var repositoryPath = ""
    @AppStorage(SettingsKey.baseBranch) private var baseBranch = GitReader.defaultBaseBranch
    @AppStorage(SettingsKey.jql) private var jql = "assignee = currentUser()"
    @AppStorage(SettingsKey.branchTemplate) private var branchTemplate = StartWork.defaultBranchTemplate

    @State private var moving: Card?
    @State private var transitions: [JiraTransition] = []

    var body: some View {
        board
            .onChange(of: baseBranch, initial: true) { model.baseBranch = baseBranch }
            .sheet(item: $moving) { card in
                TransitionSheet(
                    card: card,
                    transitions: transitions,
                    onApply: { transition in
                        moving = nil
                        Task { await model.apply(transition, to: card) }
                    },
                    onCancel: { moving = nil }
                )
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let message = model.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .help(message)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refreshJira(jql: jql) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help("Reload columns and issues from Jira")
                }
            }
    }

    private var board: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(model.columns) { column in
                    lane(column)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BoardBackground())
        .background(IconOnlyToolbar().frame(width: 0, height: 0))
    }

    private func lane(_ column: BoardColumnModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ColumnHeader(name: column.name, visible: column.cards.count, total: column.total)

            ForEach(column.cards) { card in
                CardView(
                    card: card,
                    isFocused: model.isFocused(card),
                    onOpen: { Task { await model.focus(card) } },
                    onFocusSession: { session in
                        guard let path = card.worktreePath else { return }
                        Task { await model.focus(session, in: path) }
                    },
                    onStartWork: {
                        model.startWork(
                            on: card,
                            repositoryPath: repositoryPath,
                            branch: StartWork.branch(
                                template: branchTemplate,
                                issueKey: card.issueKey ?? "",
                                summary: card.summary
                            ),
                            baseBranch: baseBranch
                        )
                    },
                    onMove: {
                        Task {
                            transitions = await model.loadTransitions(for: card)
                            moving = card
                        }
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(width: 210, alignment: .topLeading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}
