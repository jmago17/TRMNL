import EventKit
import Foundation

final class RemindersService {
    private let store = EKEventStore()
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func requestAccess() async throws {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            throw AgentError.remindersAccessDenied
        }
    }

    /// Returns titles of incomplete reminders in the named list (case-insensitive),
    /// across all accounts. Empty list if not found or list name is empty.
    func incompleteItems(in listName: String) async -> [String] {
        guard !listName.isEmpty else { return [] }
        let calendars = store.calendars(for: .reminder).filter {
            $0.title.caseInsensitiveCompare(listName) == .orderedSame
        }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: calendars
        )
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        // Orden: prioridad (1=alta, 5=media, 9=baja, 0=ninguna → al final),
        // luego fecha de creación ascendente.
        return reminders
            .sorted { lhs, rhs in
                let lp = lhs.priority == 0 ? 10 : lhs.priority
                let rp = rhs.priority == 0 ? 10 : rhs.priority
                if lp != rp { return lp < rp }
                return (lhs.creationDate ?? .distantPast) < (rhs.creationDate ?? .distantPast)
            }
            .compactMap { $0.title?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
