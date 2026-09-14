import SwiftUI
import ScrumbanCore

struct EpicChip: View {
    let epic: JiraEpic

    private var tint: Color {
        switch epic.color.replacingOccurrences(of: "dark_", with: "") {
        case "purple": .purple
        case "blue": .blue
        case "green": .green
        case "yellow": .yellow
        case "orange": .orange
        case "teal": .teal
        case "grey", "gray": .gray
        default: .accentColor
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(epic.label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }
}
