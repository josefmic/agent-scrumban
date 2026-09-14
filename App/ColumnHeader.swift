import SwiftUI

struct ColumnHeader: View {
    let name: String
    let visible: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(name.uppercased())
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(visible)/\(total)")
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())

            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}
