import XCTest

final class BoardUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    func testLaunchesWithAWindow() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    func testShowsTheRefreshControl() {
        XCTAssertTrue(app.buttons["Refresh"].waitForExistence(timeout: 10))
    }

    func testOpensSettingsFromTheMenu() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.menuBars.menuItems["Settings…"].click()

        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testSettingsExposesEveryConfigurationField() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        app.menuBars.menuItems["Settings…"].click()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))

        XCTAssertEqual(app.textFields.count, 7)
    }
}
