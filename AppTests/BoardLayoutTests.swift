import XCTest
import SwiftUI
import AppKit
import ScrumbanCore
@testable import AgentScrumban

@MainActor
final class BoardLayoutTests: XCTestCase {
    private struct Board: Equatable {
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
        CGSize(width: 1600, height: 900),
        CGSize(width: 1600, height: 600),
        CGSize(width: 900, height: 800),
        CGSize(width: 700, height: 420),
        CGSize(width: 480, height: 360),
    ]

    private static let legacyScrollers = NSScroller.preferredScrollerStyle == .legacy

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

    private func window<Content: View>(
        _ appearance: NSAppearance.Name = .aqua,
        @ViewBuilder content: () -> Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = NSHostingView(rootView: content())
        return window
    }

    private func board(_ columns: [BoardColumnModel], appearance: NSAppearance.Name = .aqua) -> NSWindow {
        window(appearance) {
            BoardScroll(columns: columns) { card in
                CardView(card: card, onOpen: {}, onFocusSession: { _ in }, onStartWork: {}, onMove: {})
            }
        }
    }

    private func scrollViews(in view: NSView, collected: inout [NSScrollView]) {
        if let found = view as? NSScrollView { collected.append(found) }
        for child in view.subviews { scrollViews(in: child, collected: &collected) }
    }

    private func layout(_ window: NSWindow, at size: CGSize) -> Board {
        window.setContentSize(size)

        for _ in 0..<6 {
            window.contentView?.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }

        var found: [NSScrollView] = []
        scrollViews(in: window.contentView!, collected: &found)
        guard let scrollView = found.first else {
            return Board(viewport: .zero, content: .zero, horizontalScroller: false, verticalScroller: false)
        }
        return Board(
            viewport: scrollView.contentSize,
            content: scrollView.documentView?.frame.size ?? .zero,
            horizontalScroller: !(scrollView.horizontalScroller?.isHidden ?? true),
            verticalScroller: !(scrollView.verticalScroller?.isHidden ?? true)
        )
    }

    private func report(_ name: String, _ size: CGSize, _ seen: Board) {
        print("LAYOUT \(name) \(Int(size.width))x\(Int(size.height)) "
            + "viewport \(seen.viewport) content \(seen.content) "
            + "h \(seen.horizontalScroller) v \(seen.verticalScroller)")
    }

    func testAScrollerAppearsOnlyOnAnAxisThatOverflows() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = board(columns(10) { $0 == 0 ? 40 : $0 % 3 }, appearance: appearance)

            for size in Self.sizes {
                let seen = layout(window, at: size)
                report("matrix/\(appearance.rawValue)", size, seen)
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
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = board(columns(4) { _ in 1 }, appearance: appearance)

            let seen = layout(window, at: CGSize(width: 1600, height: 900))
            report("fits/\(appearance.rawValue)", CGSize(width: 1600, height: 900), seen)

            XCTAssertFalse(seen.horizontalScroller, "horizontal scroller on a board that fits")
            XCTAssertFalse(seen.verticalScroller, "vertical scroller on a board that fits")
        }
    }

    func testATallColumnShowsOnlyTheVerticalScroller() {
        let window = board(columns(4) { $0 == 0 ? 60 : 1 })

        let seen = layout(window, at: CGSize(width: 1600, height: 600))
        report("tall", CGSize(width: 1600, height: 600), seen)

        XCTAssertTrue(seen.verticalScroller)
        XCTAssertFalse(seen.horizontalScroller)
    }

    func testNarrowColumnsShowOnlyTheHorizontalScroller() {
        let window = board(columns(10) { _ in 1 })

        let seen = layout(window, at: CGSize(width: 900, height: 800))
        report("narrow", CGSize(width: 900, height: 800), seen)

        XCTAssertTrue(seen.horizontalScroller)
        XCTAssertFalse(seen.verticalScroller)
    }

    func testAHorizontalScrollerNeverCostsVerticalOverflow() throws {
        try XCTSkipUnless(Self.legacyScrollers, "overlay scrollers reserve no band")
        let window = board(columns(10) { _ in 1 })

        let seen = layout(window, at: CGSize(width: 900, height: 800))

        XCTAssertTrue(seen.horizontalScroller)
        XCTAssertEqual(seen.content.height, seen.viewport.height, accuracy: 1)
    }

    func testTheBoardIsInsetByTheSameMarginOnTheLeftAndRight() {
        let window = board(columns(10) { _ in 1 })

        for size in [CGSize(width: 900, height: 800), CGSize(width: 480, height: 360)] {
            let seen = layout(window, at: size)
            let lanes = 10 * BoardScroll<EmptyView>.minimumColumnWidth
                + 9 * BoardScroll<EmptyView>.columnSpacing
            let sides = seen.content.width - lanes

            print("INSET horizontal \(Int(size.width))x\(Int(size.height)): \(sides / 2) per side")
            XCTAssertEqual(sides / 2, BoardScroll<EmptyView>.inset, accuracy: 0.5, "side inset at \(size)")
        }
    }

    func testTheBoardIsInsetByTheSameMarginOnTheTopAndBottom() {
        let cards = 30
        let cardHeight: CGFloat = 40
        let window = window {
            BoardScroll(columns: columns(4) { $0 == 0 ? cards : 0 }) { _ in
                Color.gray.frame(height: cardHeight)
            }
        }

        let seen = layout(window, at: CGSize(width: 1600, height: 600))
        let lane = CGFloat(cards) * cardHeight + CGFloat(cards + 1) * BoardScroll<EmptyView>.cardSpacing
        let ends = seen.content.height - lane - BoardScroll<EmptyView>.headerHeight

        print("INSET vertical 1600x600: \(ends / 2) per end")
        XCTAssertEqual(ends / 2, BoardScroll<EmptyView>.inset, accuracy: 0.5)
    }

    private func scroll(_ window: NSWindow, by offset: CGFloat) {
        var found: [NSScrollView] = []
        scrollViews(in: window.contentView!, collected: &found)
        guard let scrollView = found.first else { return XCTFail("no scroll view") }

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    private func headerStrip(_ window: NSWindow) -> Data {
        let view = window.contentView!
        let gutter = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        let strip = NSRect(
            x: 0,
            y: view.isFlipped ? 0 : view.bounds.height - BoardScroll<EmptyView>.inset - BoardScroll<EmptyView>.headerHeight,
            width: view.bounds.width - gutter,
            height: BoardScroll<EmptyView>.inset + BoardScroll<EmptyView>.headerHeight
        )
        guard let rep = view.bitmapImageRepForCachingDisplay(in: strip) else { return Data() }
        view.cacheDisplay(in: strip, to: rep)
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    func testCardsNeverShowThroughThePinnedHeader() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = board(columns(4) { $0 == 0 ? 60 : 1 }, appearance: appearance)
            _ = layout(window, at: CGSize(width: 1600, height: 600))

            let resting = headerStrip(window)
            XCTAssertFalse(resting.isEmpty, "no header pixels captured")

            for offset in [CGFloat(40), 200, 900] {
                scroll(window, by: offset)
                XCTAssertEqual(
                    headerStrip(window), resting,
                    "cards show through the header at offset \(offset) in \(appearance.rawValue)"
                )
            }
        }
    }

    private func onScreen(_ window: NSWindow) -> NSBitmapImageRep? {
        window.level = .floating
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        defer { window.orderOut(nil) }

        let id = CGWindowID(window.windowNumber)
        let options: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        guard let shot = CGWindowListCreateImage(.null, .optionIncludingWindow, id, options) else { return nil }
        return NSBitmapImageRep(cgImage: shot)
    }

    func testTheHeaderIsTheSameColourAsTheBoardBeneathIt() throws {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let window = board(columns(4) { $0 == 0 ? 40 : 1 }, appearance: appearance)
            _ = layout(window, at: CGSize(width: 1200, height: 700))

            let image = try XCTUnwrap(onScreen(window), "no window image in \(appearance.rawValue)")
            let chrome = image.pixelsHigh - Int(window.contentView!.frame.height)
            let margin = Int(BoardScroll<EmptyView>.inset) / 2
            let strip = chrome + margin
            let lanes = chrome + Int(BoardScroll<EmptyView>.inset + BoardScroll<EmptyView>.headerHeight) + 40

            let above = try XCTUnwrap(image.colorAt(x: margin, y: strip))
            let below = try XCTUnwrap(image.colorAt(x: margin, y: lanes))

            XCTAssertEqual(
                above, below,
                "header strip \(above) differs from the board \(below) in \(appearance.rawValue)"
            )
        }
    }

    func testRelayoutAtTheSameSizeNeverMoves() {
        let window = board(columns(10) { $0 == 0 ? 40 : $0 % 3 })

        for size in Self.sizes {
            let first = layout(window, at: size)
            let second = layout(window, at: size)
            XCTAssertEqual(first, second, "layout oscillates at \(size)")
        }
    }
}
