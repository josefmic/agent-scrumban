import Foundation

public enum SessionScreen {
    static let interruptHint = "esc to interrupt"
    static let rule: Character = "\u{2500}"
    static let shortestRule = 8

    public static func isWorking(_ rendered: String) -> Bool {
        statusLine(of: rendered)?.contains(interruptHint) ?? false
    }

    static func statusLine(of rendered: String) -> String? {
        let lines = rendered.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(visibleText(in:))
        guard let border = lines.lastIndex(where: isRule) else { return nil }

        return lines[lines.index(after: border)...].first { !$0.isEmpty }
    }

    private static func isRule(_ line: String) -> Bool {
        line.count >= shortestRule && line.allSatisfy { $0 == rule }
    }

    static func visibleText(in line: Substring) -> String {
        var text = ""
        var rest = line.unicodeScalars[...]

        while let scalar = rest.first {
            rest = rest.dropFirst()

            guard scalar == "\u{1B}" else {
                text.unicodeScalars.append(scalar)
                continue
            }

            guard let introducer = rest.first else { break }
            rest = rest.dropFirst()

            switch introducer {
            case "[":
                rest = rest.drop { $0.value < 0x40 }.dropFirst()
            case "]":
                rest = rest.drop { $0 != "\u{07}" && $0 != "\u{1B}" }
                if rest.first == "\u{1B}" { rest = rest.dropFirst() }
                rest = rest.dropFirst()
            case "(", ")", "#", "%":
                rest = rest.dropFirst()
            default:
                break
            }
        }

        return text.trimmingCharacters(in: .whitespaces)
    }
}
