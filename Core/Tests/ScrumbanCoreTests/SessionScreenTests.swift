import XCTest
@testable import ScrumbanCore

final class SessionScreenTests: XCTestCase {
    private static let border =
        "\u{1B}[0m\u{1B}[38;2;136;136;136m\(String(repeating: "\u{2500}", count: 131))\u{1B}[0m\r"
    private static let mode = "  \u{1B}[0m\u{1B}[38;2;255;193;7m⏵⏵ auto mode on\u{1B}[0m\u{1B}[38;2;153;153;153m"
    private static let cursor = "\u{1B}[0m\u{1B}[=5;1u\u{1B}(B\u{1B}[42;7H\u{1B}[>4;2m"

    func testATurnInFlightShowsTheHintOnTheStatusLine() {
        let screen = """
        \u{1B}[0m\u{1B}[38;2;255;255;255m⏺ \u{1B}[0mReading the transcript store\r
        \(Self.border)
        ❯\u{A0}\r
        \(Self.border)
        \(Self.mode) (shift+tab to cycle) · esc to interrupt · ← 3 agents\u{1B}[0m\(Self.cursor)
        """

        XCTAssertTrue(SessionScreen.isWorking(screen))
    }

    func testTranscriptTextThatQuotesTheHintIsNotWorking() {
        let screen = """
          │ \u{1B}[0m\u{1B}[38;2;177;185;249mesc to interrupt\u{1B}[0m        │ \u{1B}[0m\u{1B}[1mworking\u{1B}[0m        │\r
          Claude Code prints \u{1B}[0m\u{1B}[38;2;177;185;249mesc to interrupt \u{1B}[0mwhile a turn runs\r
        \(Self.border)
        ❯\u{A0}\u{1B}[0m\u{1B}[2mok show me when its done\u{1B}[0m\r
        \(Self.border)
        \(Self.mode) (shift+tab to cycle) · ← 3 agents · ↓ to manage\u{1B}[0m\r
        \r
        \u{1B}[0m\u{1B}[1m  ⏺ main\u{1B}[0m\r
        """

        XCTAssertFalse(SessionScreen.isWorking(screen))
    }

    func testABackgroundAgentRowThatQuotesTheHintIsNotWorking() {
        let screen = """
        \(Self.border)
        ❯\u{A0}\r
        \(Self.border)
        \(Self.mode) (shift+tab to cycle) · ← 3 agents · ↓ to manage\u{1B}[0m\r
        \r
        \u{1B}[0m\u{1B}[1m  ⏺ main\u{1B}[0m\r
        \u{1B}[0m\u{1B}[38;2;153;153;153m  ◯ general-purpose\u{1B}[0m  \u{1B}[0m\u{1B}[38;2;153;153;153mGrepping cli bundle for "esc to interrupt"          8m 27s · ↓ 146.6k\u{1B}[0m\(Self.cursor)
        """

        XCTAssertFalse(SessionScreen.isWorking(screen))
    }

    func testAnInterruptedTurnIsNotWorking() {
        let screen = """
        \u{1B}[0m\u{1B}[38;2;153;153;153m  ⎿ \u{A0}Interrupted · What should Claude do instead?\u{1B}[0m\r
        \(Self.border)
        ❯\u{A0}work\r
        \(Self.border)
        \(Self.mode) (shift+tab to cycle)\u{1B}[0m\(Self.cursor)
        """

        XCTAssertFalse(SessionScreen.isWorking(screen))
    }

    func testAFinishedTurnIsNotWorking() {
        let screen = """
        \u{1B}[0m\u{1B}[38;2;153;153;153m✻ Cooked for 1s · done 3:46 PM\u{1B}[0m\r
        \(Self.border)
        ❯\u{A0}\r
        \(Self.border)
        \(Self.mode) (shift+tab to cycle) · ← 3 agents\u{1B}[0m\(Self.cursor)
        """

        XCTAssertFalse(SessionScreen.isWorking(screen))
    }

    func testAShellWithNoPromptBoxIsNotWorking() {
        let screen = """
        Last login: Fri Sep 11 16:01:58 on ttys006\r
        user@host ABC-639-dpd-sk-carrier % \r
        """

        XCTAssertFalse(SessionScreen.isWorking(screen))
        XCTAssertNil(SessionScreen.statusLine(of: screen))
    }
}
