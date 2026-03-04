import SwiftUI

struct SettingsTabView: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Cloudflare Worker") {
                    TextField("Worker URL", text: $settings.workerURL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Auth Secret", text: $settings.authSecret)
                }

                Section("Photo Plugin") {
                    TextField("Plugin UUID", text: $settings.photoPluginUUID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Calendars") {
                    NavigationLink("Filter Calendars") {
                        CalendarPickerView()
                    }
                }

                Section("Calendar Plugins") {
                    TextField("Day Agenda UUID", text: $settings.dayAgendaPluginUUID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Week Overview UUID", text: $settings.weekOverviewPluginUUID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Month Overview UUID", text: $settings.monthOverviewPluginUUID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    if settings.isConfigured {
                        Label("Worker configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Worker URL and secret required", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
