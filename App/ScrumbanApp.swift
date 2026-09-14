import SwiftUI

@main
struct ScrumbanApp: App {
    @StateObject private var model = BoardViewModel()

    var body: some Scene {
        WindowGroup("agent-scrumban") {
            BoardView(model: model)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { model.start() }
                .onDisappear { model.stop() }
        }
        .defaultSize(width: 1960, height: 920)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }
    }
}
