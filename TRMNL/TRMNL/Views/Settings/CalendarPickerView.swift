import EventKit
import SwiftUI

struct CalendarPickerView: View {
    @State private var calendars: [EKCalendar] = []
    @State private var settings = AppSettings.shared

    private let calendarService = CalendarService()

    var body: some View {
        List {
            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                calendarRow(calendar)
            }
        }
        .navigationTitle("Calendars")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Show All") {
                    settings.selectedCalendarIdentifiers = []
                }
                .disabled(settings.selectedCalendarIdentifiers.isEmpty)
            }
        }
        .task {
            _ = try? await calendarService.requestAccess()
            calendars = await calendarService.availableCalendars()
        }
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let id = calendar.calendarIdentifier
        let isSelected = settings.selectedCalendarIdentifiers.isEmpty
            || settings.selectedCalendarIdentifiers.contains(id)

        return Button {
            toggleCalendar(id)
        } label: {
            HStack {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)
                Text(calendar.title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func toggleCalendar(_ id: String) {
        if settings.selectedCalendarIdentifiers.isEmpty {
            settings.selectedCalendarIdentifiers = Set(calendars.map(\.calendarIdentifier))
            settings.selectedCalendarIdentifiers.remove(id)
        } else if settings.selectedCalendarIdentifiers.contains(id) {
            settings.selectedCalendarIdentifiers.remove(id)
        } else {
            settings.selectedCalendarIdentifiers.insert(id)
        }
    }
}
