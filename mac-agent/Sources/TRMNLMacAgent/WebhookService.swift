import Foundation

actor WebhookService {
    private let baseURL = "https://usetrmnl.com/api/custom_plugins"
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func sendPhoto(imageURL: String) async throws {
        guard !config.photoPluginUUID.isEmpty else {
            throw AgentError.notConfigured("photoPluginUUID")
        }

        let payload = TRMNLPluginPayload(
            mergeVariables: ["image_url": .string(imageURL)]
        )
        try await post(pluginUUID: config.photoPluginUUID, payload: payload)
    }

    func sendDayAgenda(title: String, events: [[String: String]]) async throws {
        guard !config.dayAgendaPluginUUID.isEmpty else {
            throw AgentError.notConfigured("dayAgendaPluginUUID")
        }

        let payload = TRMNLPluginPayload(
            mergeVariables: [
                "title": .string(title),
                "generated_at": .string(ISO8601DateFormatter().string(from: Date())),
                "events": .array(events.map { event in
                    .object(event.mapValues { .string($0) })
                })
            ]
        )
        try await post(pluginUUID: config.dayAgendaPluginUUID, payload: payload)
    }

    func sendWeekOverview(weekTitle: String, days: [CalendarDayPayload]) async throws {
        guard !config.weekOverviewPluginUUID.isEmpty else {
            throw AgentError.notConfigured("weekOverviewPluginUUID")
        }

        let payload = TRMNLPluginPayload(
            mergeVariables: [
                "week_title": .string(weekTitle),
                "days": .array(days.map { day in
                    .object([
                        "label": .string(day.label),
                        "events": .array(day.events.map { event in
                            .object(event.mapValues { .string($0) })
                        })
                    ])
                })
            ]
        )
        try await post(pluginUUID: config.weekOverviewPluginUUID, payload: payload)
    }

    func sendMonthOverview(monthTitle: String, headers: [String], weeks: [[CalendarMonthDayPayload]]) async throws {
        guard !config.monthOverviewPluginUUID.isEmpty else {
            throw AgentError.notConfigured("monthOverviewPluginUUID")
        }

        let payload = TRMNLPluginPayload(
            mergeVariables: [
                "month_title": .string(monthTitle),
                "headers": .array(headers.map { .string($0) }),
                "weeks": .array(weeks.map { week in
                    .array(week.map { day in
                        .object([
                            "day": .string(day.day),
                            "events": .array(day.events.map { .string($0) })
                        ])
                    })
                })
            ]
        )
        try await post(pluginUUID: config.monthOverviewPluginUUID, payload: payload)
    }

    private func post(pluginUUID: String, payload: TRMNLPluginPayload) async throws {
        let rawURL = "\(baseURL)/\(pluginUUID)"
        guard let url = URL(string: rawURL) else {
            throw AgentError.invalidURL(rawURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                throw AgentError.serverErrorWithBody("TRMNL webhook", httpResponse.statusCode, body)
            }
            throw AgentError.serverError("TRMNL webhook", httpResponse.statusCode)
        }
    }
}

private struct TRMNLPluginPayload: Encodable {
    let mergeVariables: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case mergeVariables = "merge_variables"
    }
}

private enum JSONValue: Encodable {
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case .array(let array):
            var container = encoder.unkeyedContainer()
            try array.forEach { try container.encode($0) }
        case .object(let object):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in object {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
