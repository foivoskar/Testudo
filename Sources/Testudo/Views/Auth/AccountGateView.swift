import SwiftUI


struct AccountGateView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore


    var body:
        some View
    {
        Group {

            if
                store
                    .localUserProfile
                    == nil
            {
                LocalUserProfileSetupView()

            } else if
                !store
                    .applicationCredentialIsConfigured
            {
                // Existing installations arrive here once after
                // upgrading. New installations arrive here after
                // creating the local profile.
                ApplicationPasswordSetupView()

            } else if
                !store
                    .applicationSessionIsOpen
            {
                ApplicationLoginView()

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
