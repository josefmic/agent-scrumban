import SwiftUI

struct LoadingNotice: View {
    var body: some View {
        ProgressView("Reading your board from Jira…")
            .controlSize(.small)
            .foregroundStyle(.secondary)
    }
}

struct SetupNotice: View {
    let missing: [SetupField]

    private var list: String {
        missing.map(\.label).formatted(.list(type: .and))
    }

    var body: some View {
        ContentUnavailableView {
            Label("Finish setting up Jira", systemImage: "gearshape")
        } description: {
            VStack(spacing: 6) {
                Text("Still missing: \(list).")

                Text("The board is read straight from your Jira site, so it needs the site address, your account email, the project key, and an API token from your Atlassian account.")
            }
        } actions: {
            SettingsLink { Text("Open Settings…") }
        }
    }
}

struct EmptyNotice: View {
    let reason: EmptyBoard

    private var title: String {
        switch reason {
        case .noColumns: "This board has no columns"
        case .noIssues: "No issues in this sprint"
        case .hiddenByFilter: "Every issue is hidden"
        case .noWorktrees: "Nothing to show yet"
        }
    }

    private var symbol: String {
        switch reason {
        case .noColumns: "rectangle.split.3x1"
        case .noIssues: "tray"
        case .hiddenByFilter: "line.3.horizontal.decrease.circle"
        case .noWorktrees: "square.stack"
        }
    }

    private var detail: String {
        switch reason {
        case .noColumns:
            "Jira returned this project's board without any columns. Add columns to the board in Jira and refresh."
        case .noIssues:
            "The active sprint is empty. Issues appear here as soon as the sprint has any."
        case .hiddenByFilter:
            "The sprint has issues, but none of them match the JQL filter in Settings."
        case .noWorktrees:
            "The sprint is empty and no Supacode worktree is open. Start work on an issue and its worktree appears under the card."
        }
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        } actions: {
            if reason == .hiddenByFilter {
                SettingsLink { Text("Open Settings…") }
            }
        }
    }
}

struct FailureNotice: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Jira did not answer", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: onRetry)
            SettingsLink { Text("Open Settings…") }
        }
    }
}
