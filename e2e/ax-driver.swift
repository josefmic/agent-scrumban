import AppKit
import ApplicationServices
import Foundation

let bundleIdentifier = "com.agentscrumban.AgentScrumban"

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? []
}

func text(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name as String) as? String ?? ""
}

func board() -> [AXUIElement] {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
        return []
    }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var found: [AXUIElement] = []

    func visit(_ element: AXUIElement, _ depth: Int) {
        if text(element, kAXRoleAttribute as String) == "AXGroup",
           !text(element, kAXIdentifierAttribute as String).isEmpty {
            found.append(element)
            return
        }
        guard depth < 12 else { return }
        for child in children(element) { visit(child, depth + 1) }
    }

    for window in attribute(root, kAXWindowsAttribute as String) as? [AXUIElement] ?? [] { visit(window, 0) }
    return found
}

func rows(_ card: AXUIElement) -> [AXUIElement] {
    children(card).filter { text($0, kAXRoleAttribute as String) == "AXButton" }
}

func snapshot() -> [String: [String]] {
    var cards: [String: [String]] = [:]
    for card in board() {
        cards[text(card, kAXIdentifierAttribute as String)] =
            rows(card).map { text($0, kAXDescriptionAttribute as String) }
    }
    return cards
}

func card(_ identifier: String) -> AXUIElement? {
    board().first { text($0, kAXIdentifierAttribute as String) == identifier }
}

func emit(_ value: Any) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
    print(String(decoding: data, as: UTF8.self))
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "cards"

switch command {
case "cards":
    emit(snapshot())

case "press":
    guard let target = card(arguments[1]) else { print("no card \(arguments[1])"); exit(1) }
    let element = arguments.count > 2 ? rows(target)[Int(arguments[2])!] : target
    let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
    print(status == .success ? "pressed" : "failed \(status.rawValue)")
    exit(status == .success ? 0 : 1)

case "error":
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
        print("not running"); exit(1)
    }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    var messages: [String] = []

    func scan(_ element: AXUIElement, _ depth: Int) {
        if text(element, kAXRoleAttribute as String) == "AXToolbar" {
            for child in children(element) {
                let label = text(child, kAXDescriptionAttribute as String)
                if !label.isEmpty, label != "Refresh" { messages.append(label) }
            }
            return
        }
        guard depth < 12 else { return }
        for child in children(element) { scan(child, depth + 1) }
    }

    for window in attribute(root, kAXWindowsAttribute as String) as? [AXUIElement] ?? [] { scan(window, 0) }
    emit(messages)

case "handler":
    let url = URL(string: arguments[1])!
    print(NSWorkspace.shared.urlForApplication(toOpen: url)?.path ?? "none")

default:
    print("unknown command \(command)")
    exit(2)
}
