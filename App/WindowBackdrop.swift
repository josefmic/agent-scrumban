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

struct BoardScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(from: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        apply(from: view)
    }

    private func apply(from view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true
    }
}
