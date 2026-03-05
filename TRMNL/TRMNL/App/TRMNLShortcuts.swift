import AppIntents

struct TRMNLShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendPhotoToTRMNL(),
            phrases: ["Send photo to \(.applicationName)", "Display photo on \(.applicationName)"],
            shortTitle: "Send Photo",
            systemImageName: "photo"
        )
        AppShortcut(
            intent: UploadPortraitSlideshow(),
            phrases: ["Upload portraits to \(.applicationName)"],
            shortTitle: "Upload Portraits",
            systemImageName: "person.crop.rectangle.stack"
        )
        AppShortcut(
            intent: UploadLandscapeSlideshow(),
            phrases: ["Upload landscapes to \(.applicationName)"],
            shortTitle: "Upload Landscapes",
            systemImageName: "photo.stack"
        )
AppShortcut(
            intent: CheckPhotoOrientation(),
            phrases: ["Check photo orientation with \(.applicationName)"],
            shortTitle: "Check Orientation",
            systemImageName: "rectangle.portrait.and.arrow.right"
        )
        AppShortcut(
            intent: SendDayAgendaToTRMNL(),
            phrases: ["Send today's agenda to \(.applicationName)", "Update \(.applicationName) calendar"],
            shortTitle: "Day Agenda",
            systemImageName: "calendar.day.timeline.leading"
        )
        AppShortcut(
            intent: SendWeekOverviewToTRMNL(),
            phrases: ["Send week to \(.applicationName)"],
            shortTitle: "Week Overview",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: SendMonthOverviewToTRMNL(),
            phrases: ["Send month to \(.applicationName)"],
            shortTitle: "Month Overview",
            systemImageName: "calendar.badge.clock"
        )
    }
}
