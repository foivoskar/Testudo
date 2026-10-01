import SwiftUI

struct AccountGateView: View {
    @EnvironmentObject
    private var store: DReportStore

    var body: some View {
        Group {
            if store.currentUser != nil {
                ContentView()
            } else if store.hasUsers {
                LoginView()
            } else {
                CreateAdministratorView()
            }
        }
    }
}
