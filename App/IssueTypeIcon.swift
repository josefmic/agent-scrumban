import SwiftUI

struct IssueTypeIcon: View {
    let type: String

    static func appearance(for type: String) -> (symbol: String, tint: Color) {
        switch type.lowercased() {
        case "bug": ("ladybug.fill", .red)
        case "task": ("checkmark.square.fill", .blue)
        case "user story", "story": ("bookmark.fill", .green)
        case "improvement": ("arrow.up.square.fill", .green)
        case "new feature": ("plus.square.fill", .teal)
        case "technical debt": ("wrench.and.screwdriver.fill", .orange)
        case "epic": ("bolt.fill", .purple)
        default: ("questionmark.square.dashed", .secondary)
        }
    }

    var body: some View {
        let appearance = Self.appearance(for: type)

        Image(systemName: appearance.symbol)
            .font(.caption)
            .foregroundStyle(appearance.tint)
            .help(type)
    }
}
