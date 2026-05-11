import EventKit
import Foundation

struct CalendarDayPayload {
    let label: String
    let events: [[String: String]]
}

struct CalendarMonthDayPayload {
    let day: String
    let events: [String]
}

final class CalendarService {
    private let store = EKEventStore()
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            throw AgentError.calendarAccessDenied
        }
    }

    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    func dayAgendaPayload(for date: Date) -> (title: String, events: [[String: String]]) {
        let titleFormatter = DateFormatter()
        titleFormatter.locale = locale
        titleFormatter.dateFormat = "EEEE, MMM d"
        let title = titleFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let events = fetchEvents(from: startOfDay(date), to: endOfDay(date))
        let formatted = events.prefix(10).map { event -> [String: String] in
            var dict: [String: String] = [
                "time": event.isAllDay ? "Egun osoa" : timeFormatter.string(from: event.startDate),
                "name": String(event.title.prefix(40))
            ]
            if let location = event.location, !location.isEmpty {
                dict["location"] = String(location.prefix(30))
            }
            return dict
        }

        return (title, formatted)
    }

    func weekOverviewPayload(for date: Date) -> (weekTitle: String, days: [CalendarDayPayload]) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart)!

        let startFormatter = DateFormatter()
        startFormatter.locale = locale
        startFormatter.dateFormat = "MMM d"
        let endFormatter = DateFormatter()
        endFormatter.locale = locale
        endFormatter.dateFormat = "d, yyyy"
        let weekTitle = "\(startFormatter.string(from: weekStart)) - \(endFormatter.string(from: endDate))"

        let dayLabelFormatter = DateFormatter()
        dayLabelFormatter.locale = locale
        dayLabelFormatter.dateFormat = "EEE d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let days = (0..<7).map { dayOffset in
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let events = fetchEvents(from: startOfDay(dayDate), to: endOfDay(dayDate))
            let formatted = events.prefix(3).map { event in
                [
                    "time": event.isAllDay ? "All day" : timeFormatter.string(from: event.startDate),
                    "name": String(event.title.prefix(20))
                ]
            }
            return CalendarDayPayload(label: dayLabelFormatter.string(from: dayDate), events: formatted)
        }

        return (weekTitle, days)
    }

    func monthOverviewPayload(for date: Date) -> (monthTitle: String, headers: [String], weeks: [[CalendarMonthDayPayload]]) {
        let calendar = Calendar.current

        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthTitle = monthFormatter.string(from: date)

        let headers = ["Al", "As", "Az", "Og", "Or", "La", "Ig"]
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let mondayOffset = (firstWeekday + 5) % 7

        let monthStart = startOfDay(firstOfMonth)
        let monthEnd = endOfDay(calendar.date(byAdding: .day, value: range.count - 1, to: firstOfMonth)!)
        let events = fetchEvents(from: monthStart, to: monthEnd)

        var eventsByDay: [Int: [String]] = [:]
        for event in events {
            let day = calendar.component(.day, from: event.startDate)
            eventsByDay[day, default: []].append(String(event.title.prefix(13)))
            eventsByDay[day] = Array(eventsByDay[day, default: []].prefix(2))
        }

        var weeks: [[CalendarMonthDayPayload]] = []
        var currentWeek: [CalendarMonthDayPayload] = []

        for _ in 0..<mondayOffset {
            currentWeek.append(CalendarMonthDayPayload(day: "", events: []))
        }

        for day in range {
            currentWeek.append(CalendarMonthDayPayload(day: "\(day)", events: eventsByDay[day] ?? []))
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(CalendarMonthDayPayload(day: "", events: []))
            }
            weeks.append(currentWeek)
        }

        return (monthTitle, headers, weeks)
    }

    private var locale: Locale {
        Locale(identifier: config.localeIdentifier.isEmpty ? "eu_ES" : config.localeIdentifier)
    }

    private func fetchEvents(from start: Date, to end: Date) -> [EKEvent] {
        let selectedIDs = Set(config.selectedCalendarIdentifiers)
        let selectedTitles = Set(config.selectedCalendarTitles)
        let matchingCalendars = store.calendars(for: .event).filter { calendar in
            selectedIDs.contains(calendar.calendarIdentifier) || selectedTitles.contains(calendar.title)
        }
        let calendars = matchingCalendars.isEmpty ? nil : matchingCalendars
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func endOfDay(_ date: Date) -> Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(date))!
    }
}
