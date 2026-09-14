import SwiftUI

@main
struct ScrumbanApp: App {
    @StateObject private var model = BoardViewModel()

    @AppStorage(SettingsKey.site) private var site = ""
    @AppStorage(SettingsKey.email) private var email = ""
    @AppStorage(SettingsKey.projectKey) private var projectKey = ""
    @AppStorage(SettingsKey.jql) private var jql = "assignee = currentUser()"

    var body: some Scene {
        WindowGroup("agent-scrumban") {
            BoardView(model: model)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    model.start()
                    Task { await connectJira() }
                }
                .onDisappear { model.stop() }
        }
        .defaultSize(width: 1960, height: 920)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }

    private func connectJira() async {
        guard let url = URL(string: site), !site.isEmpty, !email.isEmpty, !projectKey.isEmpty else { return }
        await model.configureJira(site: url, email: email, projectKey: projectKey, jql: jql)
    }
}
