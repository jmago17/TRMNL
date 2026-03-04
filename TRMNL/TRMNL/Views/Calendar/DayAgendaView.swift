import SwiftUI

struct DayAgendaView: View {
    let date: Date
    let calendarService: CalendarService

    @State private var title = ""
    @State private var events: [[String: String]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 8)

            if events.isEmpty {
                Text("No events")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .top) {
                        Text(event["time"] ?? "")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 70, alignment: .leading)

                        VStack(alignment: .leading) {
                            Text(event["name"] ?? "")
                                .font(.body)
                            if let location = event["location"], !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: date) { await loadData() }
    }

    private func loadData() async {
        let payload = await calendarService.dayAgendaPayload(for: date)
        title = payload.title
        events = payload.events
    }
}
