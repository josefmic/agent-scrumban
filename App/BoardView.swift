import SwiftUI
import ScrumbanCore

struct BoardView: View {
    @ObservedObject var model: BoardViewModel

    @AppStorage(SettingsKey.site) private var site = ""
    @AppStorage(SettingsKey.email) private var email = ""
    @AppStorage(SettingsKey.projectKey) private var projectKey = ""
    @AppStorage(SettingsKey.repositoryPath) private var repositoryPath = ""
    @AppStorage(SettingsKey.baseBranch) private var baseBranch = GitReader.defaultBaseBranch
    @AppStorage(SettingsKey.jql) private var jql = "assignee = currentUser()"
    @AppStorage(SettingsKey.branchTemplate) private var branchTemplate = StartWork.defaultBranchTemplate

    @State private var moving: Card?
    @State private var transitions: [JiraTransition] = []

    private var setup: JiraSetup {
        JiraSetup(site: site, email: email, projectKey: projectKey, hasToken: model.hasToken)
    }

    private var phase: BoardPhase {
        BoardPhase.of(
            setup: setup,
            loaded: model.loaded,
            error: model.errorMessage,
            columns: model.columns,
            worktrees: model.worktreeCount
        )
    }

    var body: some View {
        content
            .onChange(of: baseBranch, initial: true) { model.baseBranch = baseBranch }
            .task(id: "\(site)\u{1}\(email)\u{1}\(projectKey)\u{1}\(jql)") { await connect() }
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
                    if phase == .board, let message = model.errorMessage {
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
            .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }

    private func connect(debounce: Duration = .milliseconds(400)) async {
        try? await Task.sleep(for: debounce)
        guard !Task.isCancelled else { return }

        await model.checkToken(email: email)

        let setup = setup
        guard let url = setup.url, setup.isComplete else { return }
        await model.configureJira(site: url, email: email, projectKey: projectKey, jql: jql)
    }

    private var content: some View {
        Group {
            switch phase {
            case let .setup(missing):
                SetupNotice(missing: missing)
            case .loading:
                LoadingNotice()
            case let .failed(message):
                FailureNotice(message: message) { Task { await connect(debounce: .zero) } }
            case let .empty(reason):
                EmptyNotice(reason: reason)
            case .board:
                board
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BoardBackground().ignoresSafeArea())
        .background(IconOnlyToolbar().frame(width: 0, height: 0))
    }

    private var board: some View {
        BoardLayout(columns: model.columns) { card in
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
    }
}
