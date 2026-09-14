import AppKit

protocol AppActivating: Sendable {
    func activate(bundleIdentifier: String) -> Bool
}

struct WorkspaceActivator: AppActivating {
    func activate(bundleIdentifier: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first
        else { return false }

        return app.activate(options: .activateAllWindows)
    }
}

protocol URLOpening: Sendable {
    func open(_ url: URL) -> Bool
}

struct WorkspaceOpener: URLOpening {
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

enum Supacode {
    static let bundleIdentifier = "app.supabit.supacode"
}
