import SwiftUI
import AppKit


// ============================================================
// MARK: - Export button
// ============================================================

struct TestudoUserProfileExportButton:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    var title:
        String =
            "Export My Profile…"

    @State
    private var message:
        String?

    @State
    private var messageIsError =
        false


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                6
        ) {

            Button(
                title
            ) {
                exportProfile()
            }


            if
                let message
            {
                Text(
                    message
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    messageIsError
                    ? Color.red
                    : Color.secondary
                )
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
                )
            }
        }
    }


    private func exportProfile() {

        message =
            nil

        messageIsError =
            false


        guard
            let profile =
                store
                    .localUserProfile
        else {
            message =
                "No local profile exists."

            messageIsError =
                true

            return
        }


        let panel =
            NSSavePanel()

        panel.title =
            "Export Testudo User Profile"

        panel.prompt =
            "Export Profile"

        panel.canCreateDirectories =
            true

        panel.isExtensionHidden =
            false

        panel.allowedContentTypes =
            [
                TestudoUserProfileFile
                    .contentType
            ]

        panel.nameFieldStringValue =
            TestudoUserProfileFile
                .suggestedFileName(
                    for:
                        profile
                )


        guard
            panel.runModal()
                == .OK,
            let selectedURL =
                panel.url
        else {
            return
        }


        let destinationURL =
            TestudoUserProfileFile
                .normalizedURL(
                    selectedURL
                )


        if
            let error =
                store
                    .exportLocalUserProfile(
                        to:
                            destinationURL
                    )
        {
            message =
                error

            messageIsError =
                true

        } else {

            message =
                "Profile exported as \(destinationURL.lastPathComponent)."
        }
    }
}


// ============================================================
// MARK: - First-run import card
// ============================================================

struct TestudoUserProfileImportCard:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    @State
    private var errorMessage:
        String?


    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            Text(
                "Already have a Testudo profile?"
            )
            .font(
                .headline
            )


            Text(
                "Import a .testudouser file to restore your personal profile without entering all of your information again."
            )
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            Text(
                "Work Environments are not stored in this file. After importing your profile, reopen the .testudoenv packages you want to use."
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )


            Button(
                "Import .testudouser Profile…"
            ) {
                importProfile()
            }


            if
                let errorMessage
            {
                Text(
                    errorMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .red
                )
            }
        }
        .padding(
            18
        )
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
        .background(
            .regularMaterial,
            in:
                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
        )
    }


    private func importProfile() {

        errorMessage =
            nil


        let panel =
            NSOpenPanel()

        panel.title =
            "Import Testudo User Profile"

        panel.prompt =
            "Import Profile"

        panel.canChooseFiles =
            true

        panel.canChooseDirectories =
            false

        panel.allowsMultipleSelection =
            false

        panel.allowedContentTypes =
            [
                TestudoUserProfileFile
                    .contentType
            ]


        guard
            panel.runModal()
                == .OK,
            let sourceURL =
                panel.url
        else {
            return
        }


        errorMessage =
            store
                .importLocalUserProfile(
                    from:
                        sourceURL
                )
    }
}
