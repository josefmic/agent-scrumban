import XCTest
import SwiftUI
import ViewInspector
import ScrumbanCore
@testable import AgentScrumban

@MainActor
enum SettingsDefaults {
    static func override(_ values: [String: String]) {
        UserDefaults.standard.removeVolatileDomain(forName: UserDefaults.argumentDomain)
        UserDefaults.standard.setVolatileDomain(values, forName: UserDefaults.argumentDomain)
    }

    static func clear() {
        UserDefaults.standard.removeVolatileDomain(forName: UserDefaults.argumentDomain)
    }
}

@MainActor
final class SettingsViewTests: XCTestCase {
    override func setUp() {
        SettingsDefaults.override([SettingsKey.email: "a@b.cz"])
    }

    override func tearDown() {
        SettingsDefaults.clear()
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
        SettingsDefaults.clear()
    }

    private func marker(_ sut: SettingsView) throws -> InspectableView<ViewType.Image> {
        try sut.inspect().find(ViewType.Image.self, where: { try $0.actualImage().name() == "exclamationmark.circle" })
    }

    func testMarksARequiredFieldThatIsStillEmpty() throws {
        SettingsDefaults.override([SettingsKey.site: "", SettingsKey.email: "a@b.cz", SettingsKey.projectKey: ""])

        XCTAssertNoThrow(try marker(SettingsView(runner: RecordingRunner())))
    }

    func testDropsTheMarkerOnceEveryRequiredFieldIsFilledIn() throws {
        SettingsDefaults.override([
            SettingsKey.site: "https://example.atlassian.net",
            SettingsKey.email: "a@b.cz",
            SettingsKey.projectKey: "ABC",
        ])

        XCTAssertThrowsError(try marker(SettingsView(runner: RecordingRunner())))
    }
}
