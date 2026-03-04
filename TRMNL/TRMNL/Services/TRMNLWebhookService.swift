import Foundation

actor TRMNLWebhookService {
    private let baseURL = "https://usetrmnl.com/api/custom_plugins"

    func sendPhoto(imageURL: String) async throws {
        let pluginUUID = AppSettings.shared.photoPluginUUID
        guard !pluginUUID.isEmpty else {
            throw WebhookError.missingPluginUUID
        }

        let payload: [String: Any] = [
            "merge_variables": ["image_url": imageURL]
        ]
        try await post(pluginUUID: pluginUUID, payload: payload)
    }

    func sendDayAgenda(title: String, events: [[String: String]]) async throws {
        let pluginUUID = AppSettings.shared.dayAgendaPluginUUID
        guard !pluginUUID.isEmpty else {
            throw WebhookError.missingPluginUUID
        }

        let payload: [String: Any] = [
            "merge_variables": [
                "title": title,
                "events": events
            ]
        ]
        try await post(pluginUUID: pluginUUID, payload: payload)
    }

    func sendWeekOverview(weekTitle: String, days: [[String: Any]]) async throws {
        let pluginUUID = AppSettings.shared.weekOverviewPluginUUID
        guard !pluginUUID.isEmpty else {
            throw WebhookError.missingPluginUUID
        }

        let payload: [String: Any] = [
            "merge_variables": [
                "week_title": weekTitle,
                "days": days
            ]
        ]
        try await post(pluginUUID: pluginUUID, payload: payload)
    }

    func sendMonthOverview(monthTitle: String, headers: [String], weeks: [[[String: Any]]]) async throws {
        let pluginUUID = AppSettings.shared.monthOverviewPluginUUID
        guard !pluginUUID.isEmpty else {
            throw WebhookError.missingPluginUUID
        }

        let payload: [String: Any] = [
            "merge_variables": [
                "month_title": monthTitle,
                "headers": headers,
                "weeks": weeks
            ]
        ]
        try await post(pluginUUID: pluginUUID, payload: payload)
    }

    private func post(pluginUUID: String, payload: [String: Any]) async throws {
        guard let url = URL(string: "\(baseURL)/\(pluginUUID)") else {
            throw WebhookError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw WebhookError.serverError(code)
        }
    }
}

enum WebhookError: LocalizedError {
    case missingPluginUUID
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .missingPluginUUID: return "Plugin UUID not set. Configure it in Settings."
        case .invalidURL: return "Invalid webhook URL."
        case .serverError(let code): return "TRMNL webhook error (\(code))."
        }
    }
}
