import SwiftUI
import ScrumbanCore

struct CardView: View {
    let card: Card
    var isFocused = false
    let onOpen: () -> Void
    let onFocusSession: (AgentSession) -> Void
    let onStartWork: () -> Void
    let onMove: () -> Void

    @State private var hovering = false

    private var started: Bool { card.worktreePath != nil }

    private var sessions: [AgentSession] { card.agentSessions }

    private var clickable: Bool { started || card.issueKey != nil }

    private var changes: DiffStat? {
        guard let diffstat = card.diffstat, diffstat.added + diffstat.removed > 0 else { return nil }
        return diffstat
    }

    private var chip: JiraEpic? {
        if let epic = card.epic { return epic }
        guard card.issueType.caseInsensitiveCompare("Epic") == .orderedSame, let key = card.issueKey else { return nil }
        return JiraEpic(key: key, name: "", summary: card.summary, color: card.epicColor)
    }

    private var points: String? {
        guard let points = card.storyPoints else { return nil }
        return points == points.rounded() ? String(Int(points)) : String(points)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 6) }

    private var fill: AnyShapeStyle {
        if isFocused { return AnyShapeStyle(Color.accentColor.opacity(0.16)) }
        return hovering && clickable ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.background)
    }

    private func sessionRow(_ session: AgentSession) -> some View {
        SessionRow(session: session) { onFocusSession(session) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.summary).font(.callout).lineLimit(3)

            if let chip {
                EpicChip(epic: chip)
            }

            if points != nil || !card.priority.isEmpty {
                HStack(spacing: 4) {
                    if let points {
                        Text(points)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if !card.priority.isEmpty {
                        PriorityIcon(priority: card.priority)
                    }

                    Spacer(minLength: 0)
                }
            }

            if card.issueKey != nil || card.assignee != nil {
                HStack(spacing: 4) {
                    if !card.issueType.isEmpty {
                        IssueTypeIcon(type: card.issueType)
                    }

                    if let key = card.issueKey {
                        Text(key).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if let assignee = card.assignee {
                        AssigneeAvatar(user: assignee)
                    }
                }
            }

            if card.branch != nil || changes != nil || !sessions.isEmpty {
                Divider().padding(.vertical, 3)
            }

            if card.branch != nil || changes != nil {
                HStack(spacing: 6) {
                    if let branch = card.branch {
                        Text(branch)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 0)

                    if let changes {
                        Text(verbatim: "+\(changes.added)").font(.caption2.monospaced()).foregroundStyle(.green)
                        Text(verbatim: "−\(changes.removed)").font(.caption2.monospaced()).foregroundStyle(.red)
                    }
                }
            }

            ForEach(sessions) { session in
                sessionRow(session)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: shape)
        .background(.background, in: shape)
        .opacity(started ? 1 : 0.6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: activate)
        .contextMenu {
            if card.worktreePath != nil {
                Button("Focus in Supacode", action: onOpen)
            } else if card.issueKey != nil {
                Button("Start work", action: onStartWork)
            }

            if card.issueKey != nil {
                Button("Move…", action: onMove)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(card.issueKey ?? card.summary)
        .accessibilityAction(.default, activate)
    }

    private func activate() {
        if started {
            onOpen()
        } else if card.issueKey != nil {
            onStartWork()
        }
    }
}
