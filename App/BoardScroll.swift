import SwiftUI
import ScrumbanCore

struct BoardScroll<CardContent: View>: View {
    let columns: [BoardColumnModel]
    @ViewBuilder let card: (Card) -> CardContent

    @StateObject private var viewport = BoardViewport()

    static var minimumColumnWidth: CGFloat { 210 }
    static var columnSpacing: CGFloat { 8 }
    static var inset: CGFloat { 8 }
    static var headerHeight: CGFloat { 26 }
    static var cardSpacing: CGFloat { 6 }

    private func columnWidth(for size: CGSize) -> CGFloat {
        let count = CGFloat(columns.count)
        guard count > 0 else { return Self.minimumColumnWidth }

        let gaps = Self.columnSpacing * (count - 1) + Self.inset * 2
        return max(Self.minimumColumnWidth, (size.width - gaps) / count)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = viewport.contentArea ?? proxy.size
            let width = columnWidth(for: size)
            let laneHeight = max(0, size.height - Self.headerHeight - Self.inset * 2)

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        HStack(alignment: .top, spacing: Self.columnSpacing) {
                            ForEach(columns) { column in
                                lane(column, width: width)
                            }
                        }
                        .frame(minHeight: laneHeight, alignment: .top)
                        .background(alignment: .topLeading) { backdrop(width: width) }
                        .padding(.horizontal, Self.inset)
                        .padding(.bottom, Self.inset)
                    } header: {
                        HStack(spacing: Self.columnSpacing) {
                            ForEach(columns) { column in
                                header(column, width: width)
                            }
                        }
                        .padding(.horizontal, Self.inset)
                        .padding(.top, Self.inset)
                        .background(BoardBackground())
                        .zIndex(1)
                    }
                }
                .background(BoardScrollers(viewport: viewport).frame(width: 0, height: 0))
            }
            .defaultScrollAnchor(.topLeading)
            .background {
                BoardBackground().padding(.top, Self.inset + Self.headerHeight)
            }
        }
    }

    private func backdrop(width: CGFloat) -> some View {
        HStack(spacing: Self.columnSpacing) {
            ForEach(columns) { _ in
                UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                    .frame(width: width)
            }
        }
    }

    private func header(_ column: BoardColumnModel, width: CGFloat) -> some View {
        ColumnHeader(name: column.name, visible: column.cards.count, total: column.total)
            .padding(.horizontal, Self.cardSpacing)
            .frame(width: width, height: Self.headerHeight, alignment: .leading)
            .background(.quaternary.opacity(0.4))
            .background(.bar)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    private func lane(_ column: BoardColumnModel, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Self.cardSpacing) {
            ForEach(column.cards) { card($0) }
        }
        .padding(.horizontal, Self.cardSpacing)
        .padding(.vertical, Self.cardSpacing)
        .frame(width: width, alignment: .topLeading)
    }
}
