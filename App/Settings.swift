import SwiftUI
import ScrumbanCore

enum SettingsKey {
    static let site = "jiraSite"
    static let email = "jiraEmail"
    static let projectKey = "jiraProjectKey"
    static let jql = "jiraJql"
    static let repositoryPath = "repositoryPath"
    static let baseBranch = "baseBranch"
    static let branchTemplate = "branchTemplate"
}

struct SettingsView: View {
    var runner: CommandRunner = SystemCommandRunner()

    @AppStorage(SettingsKey.site) private var site = ""
    @AppStorage(SettingsKey.email) private var email = ""
    @AppStorage(SettingsKey.projectKey) private var projectKey = ""
    @AppStorage(SettingsKey.jql) private var jql = "assignee = currentUser()"
    @AppStorage(SettingsKey.repositoryPath) private var repositoryPath = ""
    @AppStorage(SettingsKey.baseBranch) private var baseBranch = GitReader.defaultBaseBranch
    @AppStorage(SettingsKey.branchTemplate) private var branchTemplate = StartWork.defaultBranchTemplate

    @State private var token = ""
    @State private var stored = false
    @State private var failure: String?

    var body: some View {
        Form {
            Section("Jira") {
                required(site) {
                    TextField("Site", text: $site, prompt: Text("https://example.atlassian.net"))
                }
                required(email) {
                    TextField("Email", text: $email)
                }
                required(projectKey) {
                    TextField("Project key", text: $projectKey, prompt: Text("ABC"))
                }
                TextField("Filter (JQL)", text: $jql, prompt: Text("assignee = currentUser()"))
            }

            Section("API token") {
                SecureField("Token", text: $token, prompt: Text("Paste a Jira API token"))

                HStack {
                    Label(status, systemImage: statusSymbol)
                        .font(.caption)
                        .foregroundStyle(failure == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))

                    Spacer()

                    Button("Save", action: save)
                        .disabled(email.isEmpty || token.isEmpty)
                    Button("Clear", action: clear)
                        .disabled(email.isEmpty || !stored)
                }
            }

            Section("Repository") {
                TextField("Path", text: $repositoryPath)
                TextField("Base branch", text: $baseBranch)
                TextField("Branch name", text: $branchTemplate, prompt: Text(StartWork.defaultBranchTemplate))
            }

            Section {
                Text("A new branch is named from the template above, where <KEY> is the issue key and <slug> the transliterated summary. You can edit the name before the worktree is created.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("The token is kept in your login keychain, service \"agent-scrumban\", account matching the email above. It is never written to disk by this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .task(id: email) { await refresh() }
    }

    private func required(_ value: String, @ViewBuilder field: () -> some View) -> some View {
        HStack(spacing: 6) {
            field()

            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .help("The board cannot load until this is filled in")
            }
        }
    }

    private var status: String {
        if let failure { return failure }
        if email.isEmpty { return "Enter your Jira account email first" }
        return stored ? "A token is stored for \(email)" : "No token stored for \(email)"
    }

    private var statusSymbol: String {
        if failure != nil { return "exclamationmark.triangle" }
        return stored ? "checkmark.circle" : "circle.dashed"
    }

    private func refresh() async {
        let runner = runner
        let email = email
        stored = await Task.detached {
            JiraCredentials.hasStoredToken(runner: runner, email: email)
        }.value
    }

    private func save() {
        let runner = runner
        let email = email
        let token = token
        Task {
            failure = await Task.detached {
                do {
                    try JiraCredentials.storeToken(runner: runner, email: email, token: token)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if failure == nil { self.token = "" }
            await refresh()
        }
    }

    private func clear() {
        let runner = runner
        let email = email
        Task {
            failure = await Task.detached {
                do {
                    try JiraCredentials.removeToken(runner: runner, email: email)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            await refresh()
        }
    }
}
