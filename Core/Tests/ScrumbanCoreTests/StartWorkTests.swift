import XCTest
@testable import ScrumbanCore

final class StartWorkTests: XCTestCase {
    func testTransliteratesACzechSummaryIntoAnAsciiSlug() {
        let slug = StartWork.slug("První přihlášení stávajícího klienta skrze SPI do Portálu")

        XCTAssertEqual(slug, "prvni-prihlaseni-stavajiciho-klienta-skrze-spi-do-portalu")
    }

    func testCollapsesPunctuationAndTrimsTheEdges() {
        XCTAssertEqual(StartWork.slug("  Napojení: systémy / doprav —  lepší!  "), "napojeni-systemy-doprav-lepsi")
    }

    func testTruncatesALongSummaryAtAWordBoundary() {
        let slug = StartWork.slug(String(repeating: "prihlaseni ", count: 20))

        XCTAssertLessThanOrEqual(slug.count, StartWork.maxSlugLength)
        XCTAssertFalse(slug.hasSuffix("-"))
        XCTAssertTrue(slug.hasSuffix("prihlaseni"))
    }

    func testBuildsTheBranchFromTheDefaultTemplate() {
        let branch = StartWork.branch(
            template: StartWork.defaultBranchTemplate,
            issueKey: "ABC-1326",
            summary: "Přihlášení klienta"
        )

        XCTAssertEqual(branch, "f/ABC-1326-prihlaseni-klienta")
    }

    func testHonoursACustomTemplate() {
        let branch = StartWork.branch(template: "feature/<slug>-<KEY>", issueKey: "ABC-7", summary: "Widget lag")

        XCTAssertEqual(branch, "feature/widget-lag-ABC-7")
    }

    func testLeavesNoDanglingSeparatorWhenTheSummaryHasNoAsciiWords() {
        let branch = StartWork.branch(template: StartWork.defaultBranchTemplate, issueKey: "ABC-7", summary: "→ ✅ ⌘")

        XCTAssertEqual(branch, "f/ABC-7")
    }

    func testBasesANewBranchOnTheFetchedRemote() {
        XCTAssertEqual(StartWork.base("devel"), "origin/devel")
    }

    func testLeavesAnAlreadyQualifiedBaseAlone() {
        XCTAssertEqual(StartWork.base("upstream/main"), "upstream/main")
    }
}
