import XCTest
@testable import ScrumbanCore

final class SessionAgeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func label(secondsAgo: TimeInterval) -> String {
        SessionAge.label(since: now.addingTimeInterval(-secondsAgo), now: now)
    }

    func testCallsAFreshSessionJustNow() {
        XCTAssertEqual(label(secondsAgo: 12), "just now")
    }

    func testCountsMinutesUnderAnHour() {
        XCTAssertEqual(label(secondsAgo: 14 * 60), "14m")
    }

    func testCountsHoursUnderADay() {
        XCTAssertEqual(label(secondsAgo: 2 * 3_600 + 400), "2h")
    }

    func testCountsDaysBeyondThat() {
        XCTAssertEqual(label(secondsAgo: 3 * 86_400), "3d")
    }
}
