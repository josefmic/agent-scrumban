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

@MainActor
final class SettingsRequiredFieldTests: XCTestCase {
    override func tearDown() {
        for key in [SettingsKey.site, SettingsKey.email, SettingsKey.projectKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func marker(_ sut: SettingsView) throws -> InspectableView<ViewType.Image> {
        try sut.inspect().find(ViewType.Image.self, where: { try $0.actualImage().name() == "exclamationmark.circle" })
    }

    func testMarksARequiredFieldThatIsStillEmpty() throws {
        UserDefaults.standard.set("a@b.cz", forKey: SettingsKey.email)

        XCTAssertNoThrow(try marker(SettingsView(runner: RecordingRunner())))
    }

    func testDropsTheMarkerOnceEveryRequiredFieldIsFilledIn() throws {
        UserDefaults.standard.set("https://example.atlassian.net", forKey: SettingsKey.site)
        UserDefaults.standard.set("a@b.cz", forKey: SettingsKey.email)
        UserDefaults.standard.set("ABC", forKey: SettingsKey.projectKey)

        XCTAssertThrowsError(try marker(SettingsView(runner: RecordingRunner())))
    }
}
