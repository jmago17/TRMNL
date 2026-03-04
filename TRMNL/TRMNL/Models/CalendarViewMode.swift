import Foundation

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var pluginUUID: String {
        let settings = AppSettings.shared
        switch self {
        case .day: return settings.dayAgendaPluginUUID
        case .week: return settings.weekOverviewPluginUUID
        case .month: return settings.monthOverviewPluginUUID
        }
    }

    var iconName: String {
        switch self {
        case .day: return "list.bullet"
        case .week: return "calendar.day.timeline.left"
        case .month: return "calendar"
        }
    }
}
