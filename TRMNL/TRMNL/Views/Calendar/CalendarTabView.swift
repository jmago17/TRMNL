import SwiftUI

struct CalendarTabView: View {
    @State private var viewMode: CalendarViewMode = .day
    @State private var selectedDate = Date()
    @State private var calendarAccessGranted = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let calendarService = CalendarService()
    private let webhookService = TRMNLWebhookService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)

                if calendarAccessGranted {
                    previewForMode
                        .padding(.horizontal)

                    Spacer()

                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSending ? "Sending..." : "Send to TRMNL")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || viewMode.pluginUUID.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                } else {
                    Spacer()
                    ContentUnavailableView(
                        "Calendar Access Required",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Grant calendar access to preview and send events.")
                    )
                    Button("Grant Access") {
                        Task { await requestAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
            .navigationTitle("Calendar")
            .task { await requestAccess() }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Sent!", isPresented: .init(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil } }
            )) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var previewForMode: some View {
        switch viewMode {
        case .day:
            DayAgendaView(date: selectedDate, calendarService: calendarService)
        case .week:
            WeekOverviewView(date: selectedDate, calendarService: calendarService)
        case .month:
            MonthOverviewView(date: selectedDate, calendarService: calendarService)
        }
    }

    private func requestAccess() async {
        do {
            calendarAccessGranted = try await calendarService.requestAccess()
        } catch {
            errorMessage = "Calendar access denied. Please enable in Settings."
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }

        do {
            switch viewMode {
            case .day:
                let (title, events) = await calendarService.dayAgendaPayload(for: selectedDate)
                try await webhookService.sendDayAgenda(title: title, events: events)

            case .week:
                let (weekTitle, days) = await calendarService.weekOverviewPayload(for: selectedDate)
                try await webhookService.sendWeekOverview(weekTitle: weekTitle, days: days)

            case .month:
                let (monthTitle, headers, weeks) = await calendarService.monthOverviewPayload(for: selectedDate)
                try await webhookService.sendMonthOverview(monthTitle: monthTitle, headers: headers, weeks: weeks)
            }
            successMessage = "\(viewMode.rawValue) view sent to TRMNL!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
