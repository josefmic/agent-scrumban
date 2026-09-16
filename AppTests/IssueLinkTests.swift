import XCTest
import ScrumbanCore
@testable import AgentScrumban

final class IssueLinkTests: XCTestCase {
    func testBuildsTheBrowseURLForAnIssue() {
        XCTAssertEqual(
            JiraSetup.issueURL(site: URL(string: "https://etnetera.atlassian.net"), issueKey: "BBOT-1247"),
            URL(string: "https://etnetera.atlassian.net/browse/BBOT-1247")
        )
    }

    func testHasNoURLWithoutASiteOrAKey() {
        XCTAssertNil(JiraSetup.issueURL(site: nil, issueKey: "BBOT-1"))
        XCTAssertNil(JiraSetup.issueURL(site: URL(string: "https://x.atlassian.net"), issueKey: nil))
        XCTAssertNil(JiraSetup.issueURL(site: URL(string: "https://x.atlassian.net"), issueKey: ""))
    }
}
