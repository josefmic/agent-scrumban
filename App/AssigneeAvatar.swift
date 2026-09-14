import SwiftUI
import AppKit
import ScrumbanCore

struct AssigneeAvatar: View {
    let user: JiraUser

    @State private var image: Image?

    var body: some View {
        ZStack {
            Circle().fill(.quaternary)

            if let image {
                image.resizable().scaledToFill()
            } else {
                Text(user.initials)
                    .font(.caption2)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(Circle())
        .help(user.displayName)
        .task(id: user.avatarURL) {
            guard let url = user.avatarURL,
                  let data = await AvatarCache.shared.data(for: url),
                  let loaded = NSImage(data: data)
            else { return }
            image = Image(nsImage: loaded)
        }
    }
}
