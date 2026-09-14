import SwiftUI
import AppKit

struct WindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct BoardBackground: View {
    @State private var opaque = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

    var body: some View {
        Group {
            if opaque {
                Color(nsColor: .windowBackgroundColor)
            } else {
                WindowBackdrop()
            }
        }
        .ignoresSafeArea()
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
        ) { _ in
            opaque = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    }
}

struct IconOnlyToolbar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { view.window?.toolbar?.displayMode = .iconOnly }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.window?.toolbar?.displayMode = .iconOnly
    }
}

@MainActor
final class BoardViewport: NSObject, ObservableObject {
    @Published private(set) var contentArea: CGSize?

    private weak var scrollView: NSScrollView?

    func track(_ scrollView: NSScrollView) {
        guard self.scrollView !== scrollView else { return measure() }

        NotificationCenter.default.removeObserver(self)
        self.scrollView = scrollView
        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentAreaChanged),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
        measure()
    }

    @objc private func contentAreaChanged(_ notification: Notification) {
        measure()
    }

    private func measure() {
        guard let scrollView else { return }

        let area = scrollView.contentSize
        guard area.width > 0, area.height > 0, area != contentArea else { return }
        contentArea = area
    }
}

struct BoardScrollers: NSViewRepresentable {
    let viewport: BoardViewport

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        Task { @MainActor in apply(from: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        Task { @MainActor in apply(from: view) }
    }

    private func apply(from view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true
        viewport.track(scrollView)
    }
}
