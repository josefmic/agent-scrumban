import SwiftUI
import ScrumbanCore

struct BoardLayout<Content: View>: View {
    let columns: [BoardColumnModel]
    @ViewBuilder let card: (Card) -> Content

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: 0)
                    .containerRelativeFrame(.vertical, count: 1, span: 1, spacing: 0)

                VStack(alignment: .leading, spacing: 0) {
                    headers
                    lanes
                }
            }
            .background(alignment: .topLeading) {
                backdrop.padding(.top, BoardMetrics.headerHeight)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.horizontal, BoardMetrics.boardInset)
        .padding(.bottom, BoardMetrics.boardInset)
    }

    private var headers: some View {
        HStack(spacing: BoardMetrics.columnGap) {
            ForEach(columns) { column in
                slice(
                    ColumnHeader(name: column.name, visible: column.cards.count, total: column.total)
                        .padding(.horizontal, BoardMetrics.lanePadding + BoardMetrics.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: BoardMetrics.headerHeight)
                        .background(.quaternary.opacity(0.4))
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: BoardMetrics.laneCorner,
                                topTrailingRadius: BoardMetrics.laneCorner
                            )
                        )
                )
            }
        }
    }

    private var lanes: some View {
        HStack(alignment: .top, spacing: BoardMetrics.columnGap) {
            ForEach(columns) { column in
                slice(
                    VStack(alignment: .leading, spacing: BoardMetrics.cardGap) {
                        ForEach(column.cards) { card($0) }
                    }
                    .padding(BoardMetrics.lanePadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                )
            }
        }
    }

    private var backdrop: some View {
        HStack(spacing: BoardMetrics.columnGap) {
            ForEach(columns) { _ in
                slice(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: BoardMetrics.laneCorner,
                        bottomTrailingRadius: BoardMetrics.laneCorner
                    )
                    .fill(.quaternary.opacity(0.4))
                    .frame(maxWidth: .infinity)
                )
            }
        }
    }

    private func slice<Cell: View>(_ cell: Cell) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(height: 0)
                .containerRelativeFrame(
                    .horizontal,
                    count: columns.count,
                    span: 1,
                    spacing: BoardMetrics.columnGap
                )

            cell.frame(minWidth: BoardMetrics.minimumColumnWidth)
        }
    }
}
