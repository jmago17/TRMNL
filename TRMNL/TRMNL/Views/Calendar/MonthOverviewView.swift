import SwiftUI

struct MonthOverviewView: View {
    let date: Date
    let calendarService: CalendarService

    @State private var monthTitle = ""
    @State private var headers: [String] = []
    @State private var weeks: [[[String: Any]]] = []

    var body: some View {
        VStack(spacing: 4) {
            Text(monthTitle)
                .font(.headline)
                .padding(.bottom, 4)

            if !headers.isEmpty {
                // Header row
                HStack(spacing: 0) {
                    ForEach(headers, id: \.self) { header in
                        Text(header)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Week rows
                ForEach(0..<weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 0) {
                        ForEach(0..<weeks[weekIndex].count, id: \.self) { dayIndex in
                            let cell = weeks[weekIndex][dayIndex]
                            let dayStr = cell["day"] as? String ?? ""
                            let hasEvents = cell["has_events"] as? Bool ?? false

                            VStack(spacing: 2) {
                                Text(dayStr)
                                    .font(.system(size: 14, weight: .medium))
                                if hasEvents {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 6, height: 6)
                                } else {
                                    Spacer()
                                        .frame(height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                        }
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
        let payload = await calendarService.monthOverviewPayload(for: date)
        monthTitle = payload.monthTitle
        headers = payload.headers
        weeks = payload.weeks
    }
}
