import SwiftUI


struct AccountGateView: View {
    @EnvironmentObject
    private var store: DReportStore


    var body: some View {
        Group {
            if
                store.localUserProfile
                    == nil
            {
                LocalUserProfileSetupView()

            } else if
                store
                    .environmentSessionIsOpen
            {
                ContentView()

            } else {
                EnvironmentChooserView()
            }
        }
    }
}
