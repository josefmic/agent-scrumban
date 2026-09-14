import XCTest
import SwiftUI
import ViewInspector
@testable import AgentScrumban

final class ColumnHeaderTests: XCTestCase {
    func testUppercasesAMixedCaseJiraColumnName() throws {
        let sut = ColumnHeader(name: "Otestováno čeká na nasazení", visible: 3, total: 3)

        XCTAssertNoThrow(try sut.inspect().find(text: "OTESTOVÁNO ČEKÁ NA NASAZENÍ"))
    }

    func testShowsVisibleOverTotal() throws {
        let sut = ColumnHeader(name: "To Do", visible: 4, total: 10)

        XCTAssertNoThrow(try sut.inspect().find(text: "4/10"))
    }

    func testStillShowsBothNumbersWhenTheyAgree() throws {
        let sut = ColumnHeader(name: "To Do", visible: 3, total: 3)

        XCTAssertNoThrow(try sut.inspect().find(text: "3/3"))
    }
}
