import Foundation

struct Config: Decodable {
    var workerURL: String
    var authSecret: String
    var photoPluginUUID: String
    var dayAgendaPluginUUID: String
    var weekOverviewPluginUUID: String
    var monthOverviewPluginUUID: String
    var selectedCalendarIdentifiers: [String]
    var selectedCalendarTitles: [String]
    var localeIdentifier: String

    static let empty = Config(
        workerURL: "",
        authSecret: "",
        photoPluginUUID: "",
        dayAgendaPluginUUID: "",
        weekOverviewPluginUUID: "",
        monthOverviewPluginUUID: "",
        selectedCalendarIdentifiers: [],
        selectedCalendarTitles: [],
        localeIdentifier: "eu_ES"
    )

    init(
        workerURL: String,
        authSecret: String,
        photoPluginUUID: String,
        dayAgendaPluginUUID: String,
        weekOverviewPluginUUID: String,
        monthOverviewPluginUUID: String,
        selectedCalendarIdentifiers: [String],
        selectedCalendarTitles: [String],
        localeIdentifier: String
    ) {
        self.workerURL = workerURL
        self.authSecret = authSecret
        self.photoPluginUUID = photoPluginUUID
        self.dayAgendaPluginUUID = dayAgendaPluginUUID
        self.weekOverviewPluginUUID = weekOverviewPluginUUID
        self.monthOverviewPluginUUID = monthOverviewPluginUUID
        self.selectedCalendarIdentifiers = selectedCalendarIdentifiers
        self.selectedCalendarTitles = selectedCalendarTitles
        self.localeIdentifier = localeIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.workerURL = try container.decodeIfPresent(String.self, forKey: .workerURL) ?? ""
        self.authSecret = try container.decodeIfPresent(String.self, forKey: .authSecret) ?? ""
        self.photoPluginUUID = try container.decodeIfPresent(String.self, forKey: .photoPluginUUID) ?? ""
        self.dayAgendaPluginUUID = try container.decodeIfPresent(String.self, forKey: .dayAgendaPluginUUID) ?? ""
        self.weekOverviewPluginUUID = try container.decodeIfPresent(String.self, forKey: .weekOverviewPluginUUID) ?? ""
        self.monthOverviewPluginUUID = try container.decodeIfPresent(String.self, forKey: .monthOverviewPluginUUID) ?? ""
        self.selectedCalendarIdentifiers = try container.decodeIfPresent([String].self, forKey: .selectedCalendarIdentifiers) ?? []
        self.selectedCalendarTitles = try container.decodeIfPresent([String].self, forKey: .selectedCalendarTitles) ?? []
        self.localeIdentifier = try container.decodeIfPresent(String.self, forKey: .localeIdentifier) ?? "eu_ES"
    }

    static func load(from path: String?) throws -> Config {
        let url = URL(fileURLWithPath: path ?? defaultConfigPath())
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AgentError.config("Config file not found at \(url.path). Run `trmnl-mac-agent example-config`.")
        }

        let data = try Data(contentsOf: url)
        var config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            throw AgentError.config("Config file at \(url.path) is not valid JSON for TRMNL Mac Agent: \(error)")
        }
        config.applyEnvironmentOverrides()
        return config
    }

    private enum CodingKeys: String, CodingKey {
        case workerURL
        case authSecret
        case photoPluginUUID
        case dayAgendaPluginUUID
        case weekOverviewPluginUUID
        case monthOverviewPluginUUID
        case selectedCalendarIdentifiers
        case selectedCalendarTitles
        case localeIdentifier
    }

    private mutating func applyEnvironmentOverrides() {
        let env = ProcessInfo.processInfo.environment
        workerURL = env["TRMNL_WORKER_URL"] ?? workerURL
        authSecret = env["TRMNL_AUTH_SECRET"] ?? authSecret
        photoPluginUUID = env["TRMNL_PHOTO_PLUGIN_UUID"] ?? photoPluginUUID
        dayAgendaPluginUUID = env["TRMNL_DAY_AGENDA_PLUGIN_UUID"] ?? dayAgendaPluginUUID
        weekOverviewPluginUUID = env["TRMNL_WEEK_OVERVIEW_PLUGIN_UUID"] ?? weekOverviewPluginUUID
        monthOverviewPluginUUID = env["TRMNL_MONTH_OVERVIEW_PLUGIN_UUID"] ?? monthOverviewPluginUUID
    }

    private static func defaultConfigPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/trmnl-mac-agent/config.json"
    }

    static let exampleJSON = """
    {
      "workerURL": "https://your-worker.example.workers.dev",
      "authSecret": "shared-secret-used-by-your-worker",
      "photoPluginUUID": "trmnl-photo-plugin-uuid",
      "dayAgendaPluginUUID": "trmnl-day-agenda-plugin-uuid",
      "weekOverviewPluginUUID": "trmnl-week-overview-plugin-uuid",
      "monthOverviewPluginUUID": "trmnl-month-overview-plugin-uuid",
      "selectedCalendarIdentifiers": [],
      "selectedCalendarTitles": [],
      "localeIdentifier": "eu_ES"
    }
    """
}

enum AgentError: LocalizedError {
    case config(String)
    case usage(String)
    case notConfigured(String)
    case invalidURL(String)
    case invalidResponse
    case serverError(String, Int)
    case serverErrorWithBody(String, Int, String)
    case invalidImage(String)
    case noPhotosFound
    case noNetwork
    case photoAccessDenied
    case calendarAccessDenied

    var errorDescription: String? {
        switch self {
        case .config(let message), .usage(let message):
            return message
        case .notConfigured(let field):
            return "\(field) is not configured."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Unexpected response from server."
        case .serverError(let service, let code):
            return "\(service) server error (\(code))."
        case .serverErrorWithBody(let service, let code, let body):
            return "\(service) server error (\(code)): \(body)"
        case .invalidImage(let path):
            return "Could not load image at \(path)."
        case .noPhotosFound:
            return "No matching photos found."
        case .noNetwork:
            return "No network connection available. Skipping TRMNL update."
        case .photoAccessDenied:
            return "Photos access was denied. Grant access in System Settings > Privacy & Security > Photos."
        case .calendarAccessDenied:
            return "Calendar access was denied. Grant access in System Settings > Privacy & Security > Calendars."
        }
    }
}
