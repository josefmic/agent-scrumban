import XCTest
@testable import ScrumbanCore

final class SupacodeCommandTests: XCTestCase {
    func testPercentEncodesPathIntoIdentifier() {
        let id = SupacodeCommand.identifier(forPath: "/Users/j/code/my-app")

        XCTAssertEqual(id, "%2FUsers%2Fj%2Fcode%2Fmy-app%2F")
    }

    func testDoesNotDoubleAppendTrailingSlash() {
        let id = SupacodeCommand.identifier(forPath: "/Users/j/repo/")

        XCTAssertEqual(id, "%2FUsers%2Fj%2Frepo%2F")
    }

    func testBuildsFocusCommand() {
        XCTAssertEqual(SupacodeCommand.focus(worktreeId: "%2Fw%2F"), ["worktree", "focus", "-w", "%2Fw%2F"])
    }

    func testBuildsTheNewWorktreeDeeplinkSupacodeOpensItsOwnDialogFor() {
        let url = SupacodeCommand.newWorktree(
            repoId: "%2FUsers%2Fj%2Frepo%2F",
            branch: "f/ABC-1247-prvni-prihlaseni",
            base: "origin/devel"
        )

        XCTAssertEqual(
            url?.absoluteString,
            "supacode://repo/%2FUsers%2Fj%2Frepo%2F/worktree/new"
                + "?branch=f%2FABC-1247-prvni-prihlaseni&base=origin%2Fdevel&fetch=true"
        )
    }

    func testBuildsFocusedWorktreeQuery() {
        XCTAssertEqual(SupacodeCommand.focusedWorktree(), ["worktree", "list", "--focused"])
    }

    func testReadsTheFocusedIdentifier() {
        let focused = SupacodeCommand.focused(in: "%2FUsers%2Fj%2Frepo%2F\n")

        XCTAssertEqual(focused, "%2FUsers%2Fj%2Frepo%2F")
    }

    func testReportsNothingFocusedForEmptyOutput() {
        XCTAssertNil(SupacodeCommand.focused(in: "\n"))
    }

    func testReadsTheSurfaceIdentifierOutOfASessionName() {
        let surface = SupacodeCommand.surfaceIdentifier(forSession: "supa-cc376a89-4c13-4a62-9a9f-136d7dd3c9cf")

        XCTAssertEqual(surface, "CC376A89-4C13-4A62-9A9F-136D7DD3C9CF")
    }

    func testIgnoresASessionThatSupacodeDidNotStart() {
        XCTAssertNil(SupacodeCommand.surfaceIdentifier(forSession: "scratch"))
    }

    func testNamesTheWorktreeOnEverySurfaceCommand() {
        XCTAssertEqual(
            SupacodeCommand.focusSurface(worktreeId: "%2Fw%2F", tabId: "DE347C00", surfaceId: "CC376A89"),
            ["surface", "focus", "-w", "%2Fw%2F", "-t", "DE347C00", "-s", "CC376A89"]
        )
    }

    func testDecodesAnIdentifierBackIntoItsPath() {
        let path = "/Users/j/.supacode/repos/app/f/ABC-639-dpd-sk-carrier"

        XCTAssertEqual(SupacodeCommand.path(forIdentifier: SupacodeCommand.identifier(forPath: path)), path)
    }

    func testReadsEveryIdentifierInAListing() {
        XCTAssertEqual(SupacodeCommand.identifiers(in: "%2Fa%2F\n\n  %2Fb%2F  \n"), ["%2Fa%2F", "%2Fb%2F"])
    }
}
