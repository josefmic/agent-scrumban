import XCTest
@testable import ScrumbanCore

final class ShellTests: XCTestCase {
    func testThrowsWhenTheProcessExitsNonZero() {
        XCTAssertThrowsError(try SystemCommandRunner().run("/usr/bin/false", [])) { error in
            guard case let CommandError.failed(_, _, status, _) = error else {
                return XCTFail("expected CommandError.failed, got \(error)")
            }
            XCTAssertEqual(status, 1)
        }
    }

    func testCarriesTheExitStatusAndStandardErrorInTheError() {
        XCTAssertThrowsError(
            try SystemCommandRunner().run("/bin/sh", ["-c", "echo boom >&2; exit 3"])
        ) { error in
            guard case let CommandError.failed(executable, arguments, status, standardError) = error else {
                return XCTFail("expected CommandError.failed, got \(error)")
            }
            XCTAssertEqual(executable, "/bin/sh")
            XCTAssertEqual(arguments, ["-c", "echo boom >&2; exit 3"])
            XCTAssertEqual(status, 3)
            XCTAssertEqual(standardError, "boom")
        }
    }

    func testReturnsStandardOutputWhenTheProcessSucceeds() throws {
        XCTAssertEqual(try SystemCommandRunner().run("/bin/echo", ["ok"]), "ok\n")
    }
}
