import Foundation

struct Options {
    let positional: [String]
    private let values: [String: String]

    init(arguments: [String]) throws {
        var positional: [String] = []
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument.hasPrefix("--") {
                let name = String(argument.dropFirst(2))
                guard !name.isEmpty else {
                    throw AgentError.usage("Invalid option: \(argument)")
                }

                if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                    values[name] = arguments[index + 1]
                    index += 2
                } else {
                    values[name] = "true"
                    index += 1
                }
            } else {
                positional.append(argument)
                index += 1
            }
        }

        self.positional = positional
        self.values = values
    }

    func value(for name: String) -> String? {
        values[name]
    }

    func dateValue(for name: String) throws -> Date? {
        guard let raw = values[name] else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: raw) else {
            throw AgentError.usage("Invalid date for --\(name). Use yyyy-mm-dd.")
        }
        return date
    }
}
