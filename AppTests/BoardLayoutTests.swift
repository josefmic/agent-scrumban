import XCTest
import SwiftUI
import AppKit
import ScrumbanCore
@testable import AgentScrumban

@MainActor
final class BoardLayoutTests: XCTestCase {
    private struct Board: Equatable {
        let count: Int
        let viewport: CGSize
        let content: CGSize
        let horizontalScroller: Bool
        let verticalScroller: Bool

        func overflows(_ axis: Axis) -> Bool {
            switch axis {
            case .horizontal: content.width > viewport.width + 1
            case .vertical: content.height > viewport.height + 1
            }
        }
    }

    private static let sizes: [CGSize] = [
        CGSize(width: 2560, height: 1400),
        CGSize(width: 2560, height: 420),
        CGSize(width: 700, height: 1400),
        CGSize(width: 700, height: 420),
        CGSize(width: 480, height: 360),
        CGSize(width: 1960, height: 920),
    ]

    private func columns(_ count: Int, cards: (Int) -> Int) -> [BoardColumnModel] {
        (0..<count).map { index in
            BoardColumnModel(
                name: "Column \(index)",
                cards: (0..<cards(index)).map { card in
                    Card(
                        columnName: "Column \(index)",
                        issueKey: "ABC-\(index)\(card)",
                        summary: "Card \(index)-\(card)",
                        worktreePath: nil,
                        branch: nil,
                        diffstat: nil
                    )
                }
            )
        }
    }

    private func window(_ columns: [BoardColumnModel], appearance: NSAppearance.Name = .aqua) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = NSHostingView(rootView: AnyView(
            BoardLayout(columns: columns) { card in
                CardView(card: card, onOpen: {}, onFocusSession: { _ in }, onStartWork: {}, onMove: {})
            }
        ))
        return window
    }

    private func scrollViews(in view: NSView, collected: inout [NSScrollView]) {
        if let found = view as? NSScrollView { collected.append(found) }
        for child in view.subviews { scrollViews(in: child, collected: &collected) }
    }

    private func layout(_ window: NSWindow, at size: CGSize) -> Board {
        window.setContentSize(size)
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        window.contentView?.layoutSubtreeIfNeeded()

        var found: [NSScrollView] = []
        scrollViews(in: window.contentView!, collected: &found)
        guard let board = found.first else {
            return Board(count: 0, viewport: .zero, content: .zero, horizontalScroller: false, verticalScroller: false)
        }
        return Board(
            count: found.count,
            viewport: board.contentSize,
            content: board.documentView?.frame.size ?? .zero,
            horizontalScroller: !(board.horizontalScroller?.isHidden ?? true),
            verticalScroller: !(board.verticalScroller?.isHidden ?? true)
        )
    }

    func testTheWholeBoardScrollsInOneScrollView() {
        let window = window(columns(10) { $0 == 0 ? 40 : $0 % 3 })

        for size in Self.sizes {
            XCTAssertEqual(layout(window, at: size).count, 1, "more than one scroll view at \(size)")
        }
    }

    func testAScrollerAppearsOnlyOnAnAxisThatOverflows() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = window(columns(10) { $0 == 0 ? 40 : $0 % 3 }, appearance: appearance)

            for size in Self.sizes {
                let seen = layout(window, at: size)
                XCTAssertEqual(
                    seen.horizontalScroller, seen.overflows(.horizontal),
                    "horizontal at \(size) in \(appearance.rawValue): content \(seen.content) viewport \(seen.viewport)"
                )
                XCTAssertEqual(
                    seen.verticalScroller, seen.overflows(.vertical),
                    "vertical at \(size) in \(appearance.rawValue): content \(seen.content) viewport \(seen.viewport)"
                )
            }
        }
    }

    func testABoardThatFitsShowsNoScrollerAtAll() {
        let window = window(columns(4) { _ in 1 })

        let seen = layout(window, at: CGSize(width: 1600, height: 900))

        XCTAssertFalse(seen.horizontalScroller)
        XCTAssertFalse(seen.verticalScroller)
    }

    func testColumnsShareTheWindowAndStopAtTheirMinimumWidth() {
        let window = window(columns(10) { _ in 1 })

        for size in Self.sizes {
            let seen = layout(window, at: size)
            XCTAssertEqual(
                seen.content.width,
                max(seen.viewport.width, BoardMetrics.minimumBoardWidth(columns: 10)),
                accuracy: 1,
                "board width at \(size)"
            )
        }
    }

    func testATallColumnMakesTheWholeBoardTall() {
        let window = window(columns(6) { $0 == 0 ? 60 : 0 })

        let seen = layout(window, at: CGSize(width: 1600, height: 600))

        XCTAssertTrue(seen.overflows(.vertical))
        XCTAssertTrue(seen.verticalScroller)
    }

    func testASweepThroughWidthsLandsOnTheSameLayout() {
        let window = window(columns(10) { $0 == 0 ? 40 : $0 % 3 })
        let sizes = stride(from: CGFloat(480), through: 2400, by: 23).map { CGSize(width: $0, height: 760) }

        let up = sizes.map { layout(window, at: $0) }
        let down = Array(sizes.reversed().map { layout(window, at: $0) }.reversed())

        for (index, pair) in zip(up, down).enumerated() {
            XCTAssertEqual(pair.0.content.height, pair.1.content.height, "height at \(sizes[index].width)")
            XCTAssertEqual(pair.0.horizontalScroller, pair.1.horizontalScroller, "scroller at \(sizes[index].width)")
            XCTAssertEqual(pair.0.verticalScroller, pair.1.verticalScroller, "scroller at \(sizes[index].width)")
            XCTAssertEqual(
                pair.0.content.width, pair.1.content.width, accuracy: 1,
                "width at \(sizes[index].width)"
            )
        }
    }

    func testASweepWithFixedHeightCardsLandsOnTheSameLayout() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        let model = columns(10) { $0 == 0 ? 40 : $0 % 3 }
        window.contentView = NSHostingView(rootView: AnyView(
            BoardLayout(columns: model) { _ in Color.gray.frame(height: 40) }
        ))
        let sizes = stride(from: CGFloat(480), through: 2400, by: 23).map { CGSize(width: $0, height: 760) }

        let up = sizes.map { layout(window, at: $0) }
        let down = Array(sizes.reversed().map { layout(window, at: $0) }.reversed())

        for (index, pair) in zip(up, down).enumerated() where pair.0.content.height != pair.1.content.height {
            XCTFail("width \(sizes[index].width): up \(pair.0.content) down \(pair.1.content)")
        }
    }

    func testASweepThroughHeightsLandsOnTheSameLayout() {
        let window = window(columns(10) { $0 == 0 ? 6 : $0 % 3 })
        let sizes = stride(from: CGFloat(360), through: 1400, by: 19).map { CGSize(width: 1600, height: $0) }

        let up = sizes.map { layout(window, at: $0) }
        let down = Array(sizes.reversed().map { layout(window, at: $0) }.reversed())

        for (index, pair) in zip(up, down).enumerated() {
            XCTAssertEqual(pair.0.horizontalScroller, pair.1.horizontalScroller, "scroller at \(sizes[index].height)")
            XCTAssertEqual(pair.0.verticalScroller, pair.1.verticalScroller, "scroller at \(sizes[index].height)")
            XCTAssertEqual(pair.0.content.width, pair.1.content.width, accuracy: 1, "width at \(sizes[index].height)")
            XCTAssertEqual(pair.0.content.height, pair.1.content.height, accuracy: 1, "height at \(sizes[index].height)")
        }
    }

    func testAHorizontalScrollerCostsOneScrollerBandOfVerticalOverflow() {
        let window = window(columns(10) { _ in 1 })
        let band = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)

        let seen = layout(window, at: CGSize(width: 900, height: 800))

        XCTAssertTrue(seen.horizontalScroller)
        XCTAssertEqual(seen.content.height - seen.viewport.height, band, accuracy: 1)
    }

    func testRelayoutAtTheSameSizeNeverMoves() {
        let window = window(columns(10) { $0 == 0 ? 40 : $0 % 3 })

        for size in Self.sizes {
            let first = layout(window, at: size)
            let second = layout(window, at: size)
            XCTAssertEqual(first, second, "layout oscillates at \(size)")
        }
    }

    func testBoardWidthTracksTheWindowWithoutShrinking() {
        let window = window(columns(10) { _ in 2 })
        var previous: CGFloat = 0

        for width in stride(from: CGFloat(480), through: 3000, by: 17) {
            let seen = layout(window, at: CGSize(width: width, height: 760))
            XCTAssertGreaterThanOrEqual(seen.content.width, previous - 1, "board shrank at \(width)")
            previous = seen.content.width
        }
    }
}
