import Foundation

public enum SessionAge {
    public static func label(since start: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(start))

        return switch seconds {
        case ..<60: "just now"
        case ..<3_600: "\(seconds / 60)m"
        case ..<86_400: "\(seconds / 3_600)h"
        default: "\(seconds / 86_400)d"
        }
    }
}
