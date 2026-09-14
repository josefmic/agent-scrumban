import CoreGraphics

enum BoardMetrics {
    static let minimumColumnWidth: CGFloat = 210
    static let boardInset: CGFloat = 8
    static let columnGap: CGFloat = 6
    static let lanePadding: CGFloat = 5
    static let cardGap: CGFloat = 5
    static let cardPadding: CGFloat = 7
    static let cardRowGap: CGFloat = 5
    static let headerHeight: CGFloat = 22
    static let laneCorner: CGFloat = 6
    static let cardCorner: CGFloat = 5

    static func minimumBoardWidth(columns: Int) -> CGFloat {
        guard columns > 0 else { return minimumColumnWidth }
        return CGFloat(columns) * minimumColumnWidth + CGFloat(columns - 1) * columnGap
    }
}
