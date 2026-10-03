import SwiftUI
import Foundation

@main
struct DReportApp: App {
    @StateObject
    private var store = DReportStore()

    var body: some Scene {
        WindowGroup {
            AccountGateView()
                .environmentObject(store)
        .environment(
            \.timeZone,
            TimeZone.autoupdatingCurrent
        )
        }
        .defaultSize(
            width: 1250,
            height: 760
        )
        .windowStyle(.hiddenTitleBar)

        Settings {
            ApplicationSettingsGateView()
                .environmentObject(store)
        .environment(
            \.timeZone,
            TimeZone.autoupdatingCurrent
        )
        }
    }
}
