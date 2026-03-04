import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var workerURL: String {
        didSet { UserDefaults.standard.set(workerURL, forKey: "workerURL") }
    }

    var authSecret: String {
        didSet { UserDefaults.standard.set(authSecret, forKey: "authSecret") }
    }

    var photoPluginUUID: String {
        didSet { UserDefaults.standard.set(photoPluginUUID, forKey: "photoPluginUUID") }
    }

    var dayAgendaPluginUUID: String {
        didSet { UserDefaults.standard.set(dayAgendaPluginUUID, forKey: "dayAgendaPluginUUID") }
    }

    var weekOverviewPluginUUID: String {
        didSet { UserDefaults.standard.set(weekOverviewPluginUUID, forKey: "weekOverviewPluginUUID") }
    }

    var monthOverviewPluginUUID: String {
        didSet { UserDefaults.standard.set(monthOverviewPluginUUID, forKey: "monthOverviewPluginUUID") }
    }

    var selectedCalendarIdentifiers: Set<String> {
        didSet { UserDefaults.standard.set(Array(selectedCalendarIdentifiers), forKey: "selectedCalendarIdentifiers") }
    }

    var isConfigured: Bool {
        !workerURL.isEmpty && !authSecret.isEmpty
    }

    private init() {
        self.workerURL = UserDefaults.standard.string(forKey: "workerURL") ?? ""
        self.authSecret = UserDefaults.standard.string(forKey: "authSecret") ?? ""
        self.photoPluginUUID = UserDefaults.standard.string(forKey: "photoPluginUUID") ?? ""
        self.dayAgendaPluginUUID = UserDefaults.standard.string(forKey: "dayAgendaPluginUUID") ?? ""
        self.weekOverviewPluginUUID = UserDefaults.standard.string(forKey: "weekOverviewPluginUUID") ?? ""
        self.monthOverviewPluginUUID = UserDefaults.standard.string(forKey: "monthOverviewPluginUUID") ?? ""
        let saved = UserDefaults.standard.stringArray(forKey: "selectedCalendarIdentifiers") ?? []
        self.selectedCalendarIdentifiers = Set(saved)
    }
}
