import SwiftUI

@main
struct DReportApp: App {
    @StateObject
    private var store = DReportStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(
            width: 1250,
            height: 760
        )

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
