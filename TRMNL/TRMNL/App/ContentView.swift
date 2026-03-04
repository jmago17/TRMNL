import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PhotosTabView()
                .tabItem {
                    Label("Photos", systemImage: "photo")
                }

            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
