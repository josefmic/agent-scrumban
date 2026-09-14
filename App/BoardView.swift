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
        .background(BoardBackground())
        .background(IconOnlyToolbar().frame(width: 0, height: 0))
    }

    private static let minimumColumnWidth: CGFloat = 210
    private static let columnSpacing: CGFloat = 8
    private static let boardInset: CGFloat = 10
    private static let headerHeight: CGFloat = 26

    private func columnWidth(for viewport: CGSize) -> CGFloat {
        let count = CGFloat(model.columns.count)
        guard count > 0 else { return Self.minimumColumnWidth }

        let gaps = Self.columnSpacing * (count - 1) + Self.boardInset * 2
        return max(Self.minimumColumnWidth, (viewport.width - gaps) / count)
    }

    private var board: some View {
        GeometryReader { proxy in
            let width = columnWidth(for: proxy.size)

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        HStack(alignment: .top, spacing: Self.columnSpacing) {
                            ForEach(model.columns) { column in
                                cards(column, width: width)
                            }
                        }
                        .frame(minHeight: proxy.size.height - Self.headerHeight, alignment: .top)
                        .background(alignment: .topLeading) { backdrop(width: width) }
                        .padding(.horizontal, Self.boardInset)
                    } header: {
                        HStack(spacing: Self.columnSpacing) {
                            ForEach(model.columns) { column in
                                header(column, width: width)
                            }
                        }
                        .padding(.horizontal, Self.boardInset)
                    }
                }
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
                .background(ScrollerCorner().frame(width: 0, height: 0))
            }
        }
    }

    private func backdrop(width: CGFloat) -> some View {
        HStack(spacing: Self.columnSpacing) {
            ForEach(model.columns) { _ in
                UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                    .frame(width: width)
            }
        }
    }

    private func header(_ column: BoardColumnModel, width: CGFloat) -> some View {
        ColumnHeader(name: column.name, visible: column.cards.count, total: column.total)
            .padding(.horizontal, 6)
            .frame(width: width, height: Self.headerHeight, alignment: .leading)
            .background(.quaternary.opacity(0.4))
            .background(.bar)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    private func cards(_ column: BoardColumnModel, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .frame(width: width, alignment: .topLeading)
    }
}
