import SwiftUI
import Foundation

@main
struct TestudoApp: App {
    @StateObject
    private var store = TestudoStore()

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
