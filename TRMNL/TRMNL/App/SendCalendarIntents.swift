import AppIntents

struct SendDayAgendaToTRMNL: AppIntent {
    static var title: LocalizedStringResource = "Send Day Agenda to TRMNL"
    static var description = IntentDescription("Sends today's calendar agenda to your TRMNL display.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendarService = CalendarService()
        _ = try await calendarService.requestAccess()
        let (title, events) = await calendarService.dayAgendaPayload(for: Date())
        try await TRMNLWebhookService().sendDayAgenda(title: title, events: events)
        return .result(dialog: "Day agenda sent to TRMNL!")
    }
}

struct SendWeekOverviewToTRMNL: AppIntent {
    static var title: LocalizedStringResource = "Send Week Overview to TRMNL"
    static var description = IntentDescription("Sends this week's calendar to your TRMNL display.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendarService = CalendarService()
        _ = try await calendarService.requestAccess()
        let (weekTitle, days) = await calendarService.weekOverviewPayload(for: Date())
        try await TRMNLWebhookService().sendWeekOverview(weekTitle: weekTitle, days: days)
        return .result(dialog: "Week overview sent to TRMNL!")
    }
}

struct SendMonthOverviewToTRMNL: AppIntent {
    static var title: LocalizedStringResource = "Send Month Overview to TRMNL"
    static var description = IntentDescription("Sends this month's calendar to your TRMNL display.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendarService = CalendarService()
        _ = try await calendarService.requestAccess()
        let (monthTitle, headers, weeks) = await calendarService.monthOverviewPayload(for: Date())
        try await TRMNLWebhookService().sendMonthOverview(monthTitle: monthTitle, headers: headers, weeks: weeks)
        return .result(dialog: "Month overview sent to TRMNL!")
    }
}
