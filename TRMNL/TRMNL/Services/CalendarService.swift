import EventKit
import Foundation

actor CalendarService {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    // MARK: - Day Agenda

    func dayAgendaPayload(for date: Date) -> (title: String, events: [[String: String]]) {
        let titleFormatter = DateFormatter()
        titleFormatter.locale = Locale(identifier: "eu_ES")
        titleFormatter.dateFormat = "EEEE, MMM d"
        let title = titleFormatter.string(from: date)

        let events = fetchEvents(from: startOfDay(date), to: endOfDay(date))
        let formatted = events.prefix(10).map { event -> [String: String] in
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

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

    // MARK: - Week Overview

    func weekOverviewPayload(for date: Date) -> (weekTitle: String, days: [[String: Any]]) {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start

        let basque = Locale(identifier: "eu_ES")
        let startFormatter = DateFormatter()
        startFormatter.locale = basque
        startFormatter.dateFormat = "MMM d"
        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let endFormatter = DateFormatter()
        endFormatter.locale = basque
        endFormatter.dateFormat = "d, yyyy"
        let weekTitle = "\(startFormatter.string(from: weekStart)) – \(endFormatter.string(from: endDate))"

        let dayLabelFormatter = DateFormatter()
        dayLabelFormatter.locale = basque
        dayLabelFormatter.dateFormat = "EEE d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var days: [[String: Any]] = []
        for dayOffset in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let dayEvents = fetchEvents(from: startOfDay(dayDate), to: endOfDay(dayDate))
            let formatted = dayEvents.prefix(3).map { event -> [String: String] in
                [
                    "time": event.isAllDay ? "All day" : timeFormatter.string(from: event.startDate),
                    "name": String(event.title.prefix(20))
                ]
            }
            days.append([
                "label": dayLabelFormatter.string(from: dayDate),
                "events": formatted
            ])
        }

        return (weekTitle, days)
    }

    // MARK: - Month Overview

    func monthOverviewPayload(for date: Date) -> (monthTitle: String, headers: [String], weeks: [[[String: Any]]]) {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "eu_ES")
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthTitle = monthFormatter.string(from: date)

        let headers = ["Al", "As", "Az", "Og", "Or", "La", "Ig"]

        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!

        // Get weekday of first day (1=Sun...7=Sat), convert to Mon-based (0=Mon...6=Sun)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let mondayOffset = (firstWeekday + 5) % 7

        // Fetch all events for the month
        let monthStart = startOfDay(firstOfMonth)
        let monthEnd = endOfDay(calendar.date(byAdding: .day, value: range.count - 1, to: firstOfMonth)!)
        let allEvents = fetchEvents(from: monthStart, to: monthEnd)
        var daysWithEvents = Set<Int>()
        for event in allEvents {
            let day = calendar.component(.day, from: event.startDate)
            daysWithEvents.insert(day)
        }

        var weeks: [[[String: Any]]] = []
        var currentWeek: [[String: Any]] = []

        // Pad beginning
        for _ in 0..<mondayOffset {
            currentWeek.append(["day": "", "has_events": false])
        }

        for day in range {
            currentWeek.append([
                "day": "\(day)",
                "has_events": daysWithEvents.contains(day)
            ])
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }

        // Pad end
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(["day": "", "has_events": false])
            }
            weeks.append(currentWeek)
        }

        return (monthTitle, headers, weeks)
    }

    // MARK: - Helpers

    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    private func fetchEvents(from start: Date, to end: Date) -> [EKEvent] {
        let selectedIDs = AppSettings.shared.selectedCalendarIdentifiers
        let calendars: [EKCalendar]? = selectedIDs.isEmpty
            ? nil
            : store.calendars(for: .event).filter { selectedIDs.contains($0.calendarIdentifier) }
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
