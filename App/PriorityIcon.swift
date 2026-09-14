import SwiftUI

struct PriorityIcon: View {
    let priority: String

    static func appearance(for priority: String) -> (symbol: String, tint: Color) {
        switch priority.lowercased() {
        case "critical": ("arrow.up.circle.fill", .red)
        case "major": ("arrow.up.circle", .orange)
        case "minor": ("arrow.down.circle", .blue)
        default: ("minus.circle", .secondary)
        }
    }

    var body: some View {
        let appearance = Self.appearance(for: priority)

        Image(systemName: appearance.symbol)
            .font(.caption)
            .foregroundStyle(appearance.tint)
            .help(priority)
    }
}
