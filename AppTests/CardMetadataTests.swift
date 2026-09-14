import XCTest
import SwiftUI
import ScrumbanCore
@testable import AgentScrumban

final class CardMetadataTests: XCTestCase {
    func testGivesEveryIssueTypeOnThisBoardItsOwnSymbol() {
        let types = ["Task", "User story", "Bug", "Improvement", "New Feature", "Technical debt", "Epic"]

        let symbols = types.map { IssueTypeIcon.appearance(for: $0).symbol }

        XCTAssertEqual(Set(symbols).count, types.count)
        XCTAssertEqual(IssueTypeIcon.appearance(for: "Bug").symbol, "ladybug.fill")
        XCTAssertEqual(IssueTypeIcon.appearance(for: "Bug").tint, .red)
    }

    func testMatchesTheIssueTypeRegardlessOfCase() {
        XCTAssertEqual(IssueTypeIcon.appearance(for: "user story").symbol, IssueTypeIcon.appearance(for: "User story").symbol)
    }

    func testFallsBackToANeutralSymbolForAnUnknownIssueType() {
        let appearance = IssueTypeIcon.appearance(for: "Podúkol")

        XCTAssertFalse(appearance.symbol.isEmpty)
        XCTAssertEqual(appearance.tint, .secondary)
    }

    func testPointsUrgentPrioritiesUpAndMinorDown() {
        XCTAssertEqual(PriorityIcon.appearance(for: "Critical").symbol, "arrow.up.circle.fill")
        XCTAssertEqual(PriorityIcon.appearance(for: "Major").symbol, "arrow.up.circle")
        XCTAssertEqual(PriorityIcon.appearance(for: "Normal").symbol, "minus.circle")
        XCTAssertEqual(PriorityIcon.appearance(for: "Minor").symbol, "arrow.down.circle")
    }

    func testFallsBackToTheNeutralPrioritySymbol() {
        XCTAssertEqual(PriorityIcon.appearance(for: "Blocker").symbol, "minus.circle")
    }

    func testGivesEveryHarnessItsOwnSymbol() {
        let symbols = AgentKind.allCases.map { HarnessBadge.symbol(for: $0) }

        XCTAssertEqual(Set(symbols).count, AgentKind.allCases.count)
        XCTAssertFalse(symbols.contains(HarnessBadge.symbol(for: nil)))
    }
}
