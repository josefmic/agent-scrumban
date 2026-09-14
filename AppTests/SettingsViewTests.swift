import XCTest
import SwiftUI
import ViewInspector
import ScrumbanCore
@testable import AgentScrumban

@MainActor
final class SettingsViewTests: XCTestCase {
    override func setUp() {
        UserDefaults.standard.set("a@b.cz", forKey: SettingsKey.email)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SettingsKey.email)
    }

    func testOffersASecureFieldForTheToken() throws {
        let sut = SettingsView(runner: RecordingRunner())

        XCTAssertNoThrow(try sut.inspect().find(ViewType.SecureField.self))
    }

    func testSaysWhereTheTokenIsKept() throws {
        let sut = SettingsView(runner: RecordingRunner())

        XCTAssertNoThrow(try sut.inspect().find(textWhere: { text, _ in text.contains("login keychain") }))
    }

    func testTellsTheUserNoTokenIsStoredYet() throws {
        let sut = SettingsView(runner: RecordingRunner())

        XCTAssertNoThrow(try sut.inspect().find(text: "No token stored for a@b.cz"))
    }
}
