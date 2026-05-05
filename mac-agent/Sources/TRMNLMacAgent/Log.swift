import Foundation

enum Log {
    static func info(_ message: String) {
        print("[\(timestamp())] \(message)")
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        return formatter.string(from: Date())
    }
}
