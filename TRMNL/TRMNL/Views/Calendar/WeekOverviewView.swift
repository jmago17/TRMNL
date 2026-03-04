import SwiftUI

struct WeekOverviewView: View {
    let date: Date
    let calendarService: CalendarService

    @State private var weekTitle = ""
    @State private var days: [[String: Any]] = []

    var body: some View {
        VStack(spacing: 4) {
            Text(weekTitle)
                .font(.headline)
                .padding(.bottom, 4)

            if !days.isEmpty {
                HStack(alignment: .top, spacing: 2) {
                    ForEach(0..<days.count, id: \.self) { index in
                        let day = days[index]
                        VStack(spacing: 2) {
                            Text(day["label"] as? String ?? "")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .lineLimit(1)

                            Divider()

                            let events = day["events"] as? [[String: String]] ?? []
                            if events.isEmpty {
                                Text("—")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                                    VStack(spacing: 0) {
                                        Text(event["time"] ?? "")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text(event["name"] ?? "")
                                            .font(.system(size: 10))
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(2)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: date) { await loadData() }
    }

    private func loadData() async {
        let payload = await calendarService.weekOverviewPayload(for: date)
        weekTitle = payload.weekTitle
        days = payload.days
    }
}
