import SwiftUI

@main
struct DReportApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1250, height: 760)

        Settings {
            SettingsView()
        }
    }
}
