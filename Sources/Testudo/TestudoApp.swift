import SwiftUI
import Foundation
import AppKit


@main
struct TestudoApp:
    App
{
    @StateObject
    private var store =
        TestudoStore()


    var body:
        some Scene
    {
        WindowGroup {
            AccountGateView()
                .environmentObject(
                    store
                )
                .environment(
                    \.timeZone,
                    TimeZone.autoupdatingCurrent
                )
        }
        .defaultSize(
            width:
                1250,
            height:
                760
        )
        .windowStyle(
            .hiddenTitleBar
        )
        .commands {
            CommandGroup(
                replacing:
                    .appInfo
            ) {
                Button(
                    "About Testudo"
                ) {
                    TestudoAboutWindow
                        .show()
                }
            }
        }


        Settings {
            ApplicationSettingsGateView()
                .environmentObject(
                    store
                )
                .environment(
                    \.timeZone,
                    TimeZone.autoupdatingCurrent
                )
        }
    }
}


// ============================================================
// MARK: - About Testudo
// ============================================================

@MainActor
private enum TestudoAboutWindow
{
    private static var window:
        NSWindow?


    static func show()
    {
        if
            let window
        {
            window
                .makeKeyAndOrderFront(
                    nil
                )

            NSApp
                .activate()

            return
        }


        let view =
            AboutTestudoView()


        let hostingController =
            NSHostingController(
                rootView:
                    view
            )


        let aboutWindow =
            NSWindow(
                contentRect:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            660,
                        height:
                            480
                    ),
                styleMask:
                    [
                        .titled,
                        .closable,
                        .miniaturizable,
                        .resizable,
                    ],
                backing:
                    .buffered,
                defer:
                    false
            )


        aboutWindow.title =
            "About Testudo"

        aboutWindow.titleVisibility =
            .visible

        aboutWindow.titlebarAppearsTransparent =
            false

        aboutWindow.isReleasedWhenClosed =
            false

        aboutWindow.contentViewController =
            hostingController

        // NSHostingController can otherwise shrink the window
        // toward the SwiftUI view's intrinsic fitting size.
        // Explicitly establish the intended About content size
        // after installing the hosting controller.
        aboutWindow.setContentSize(
            NSSize(
                width:
                    660,
                height:
                    480
            )
        )

        aboutWindow.minSize =
            NSSize(
                width:
                    620,
                height:
                    450
            )

        aboutWindow.center()


        window =
            aboutWindow


        aboutWindow
            .makeKeyAndOrderFront(
                nil
            )

        NSApp
            .activate()
    }
}


// ============================================================
// MARK: - About View
//
// Deliberately contains no ScrollView.
// The complete About content is visible inside the window.
// ============================================================

private struct AboutTestudoView:
    View
{
    private var version:
        String
    {
        Bundle.main
            .object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            )
            as? String
        ?? "Unknown"
    }


    private var build:
        String
    {
        Bundle.main
            .object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            )
            as? String
        ?? "Unknown"
    }


    private var applicationIcon:
        NSImage
    {
        NSApplication
            .shared
            .applicationIconImage
        ?? NSImage(
            systemSymbolName:
                "tortoise",
            accessibilityDescription:
                "Testudo"
        )
        ?? NSImage()
    }


    var body:
        some View
    {
        VStack(
            spacing:
                0
        ) {

            Image(
                nsImage:
                    applicationIcon
            )
            .resizable()
            .scaledToFit()
            .frame(
                width:
                    104,
                height:
                    104
            )


            Text(
                "Testudo"
            )
            .font(
                .system(
                    size:
                        30,
                    weight:
                        .semibold
                )
            )
            .padding(
                .top,
                12
            )


            Text(
                "Version \(version) · Build \(build)"
            )
            .font(
                .system(
                    size:
                        13,
                    weight:
                        .medium
                )
            )
            .foregroundStyle(
                .secondary
            )
            .padding(
                .top,
                4
            )


            Divider()
                .padding(
                    .vertical,
                    22
                )


            VStack(
                spacing:
                    14
            ) {

                Text(
                    "A native, local-first macOS environment for structured professional and research work."
                )
                .font(
                    .system(
                        size:
                            15,
                        weight:
                            .medium
                    )
                )
                .multilineTextAlignment(
                    .center
                )
                .lineLimit(
                    nil
                )
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
                )


                Text(
                    "Testudo helps organize interconnected Tasks, Notes, Activities, People, Organizations, Themes, work history and calendar information while keeping data under the user's control."
                )
                .font(
                    .system(
                        size:
                            13
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .lineLimit(
                    nil
                )
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
                )
                .lineSpacing(
                    3
                )


                Text(
                    "Local-first · macOS 26+ · Apple Silicon"
                )
                .font(
                    .system(
                        size:
                            12,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Divider()
                .padding(
                    .vertical,
                    22
                )


            VStack(
                spacing:
                    8
            ) {

                Text(
                    "Created by Foivos Karakostas"
                )
                .font(
                    .system(
                        size:
                            13,
                        weight:
                            .medium
                    )
                )


                Text(
                    "Copyright © 2026 Foivos Karakostas"
                )
                .font(
                    .system(
                        size:
                            12
                    )
                )
                .foregroundStyle(
                    .secondary
                )


                HStack(
                    spacing:
                        18
                ) {

                    Link(
                        "GitHub",
                        destination:
                            URL(
                                string:
                                    "https://github.com/foivoskar/Testudo"
                            )!
                    )


                    Link(
                        "MIT License",
                        destination:
                            URL(
                                string:
                                    "https://github.com/foivoskar/Testudo/blob/main/LICENSE"
                            )!
                    )
                }
                .font(
                    .system(
                        size:
                            13,
                        weight:
                            .medium
                    )
                )
                .padding(
                    .top,
                    4
                )
            }
        }
        .frame(
            minWidth:
                580,
            idealWidth:
                620,
            maxWidth:
                .infinity,
            minHeight:
                410,
            idealHeight:
                440
        )
        .padding(
            .horizontal,
            38
        )
        .padding(
            .vertical,
            30
        )
    }
}
