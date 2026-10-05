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

            CommandGroup(
                replacing:
                    .printItem
            ) {
                Button(
                    "Print…"
                ) {
                    TestudoPrintController
                        .printCurrentView()
                }
                .keyboardShortcut(
                    "p",
                    modifiers:
                        .command
                )
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
// MARK: - Printing
// ============================================================

@MainActor
private enum TestudoPrintController
{
    private struct CapturedChunk
    {
        let image:
            NSImage

        let y:
            CGFloat

        let height:
            CGFloat
    }


    static func printCurrentView()
    {
        guard
            let window =
                NSApp.keyWindow
                ?? NSApp.mainWindow,
            let rootView =
                window.contentView,
            let detailView =
                detailPane(
                    in:
                        rootView
                )
        else {
            NSSound.beep()
            return
        }

        window.displayIfNeeded()
        rootView.layoutSubtreeIfNeeded()
        detailView.layoutSubtreeIfNeeded()

        let printableView:
            NSView

        if
            let scrollView =
                printableScrollView(
                    in:
                        detailView
                ),
            let fullView =
                captureScrollableContent(
                    scrollView:
                        scrollView,
                    rootView:
                        rootView,
                    window:
                        window
                )
        {
            printableView =
                fullView

        } else if
            let visibleView =
                captureVisibleDetail(
                    detailView:
                        detailView,
                    rootView:
                        rootView,
                    window:
                        window
                )
        {
            printableView =
                visibleView

        } else {
            NSSound.beep()
            return
        }

        let printInfo =
            NSPrintInfo.shared
                .copy()
                as! NSPrintInfo

        printInfo.scalingFactor =
            0.90

        printInfo.horizontalPagination =
            .fit

        printInfo.verticalPagination =
            .automatic

        printInfo.isHorizontallyCentered =
            true

        printInfo.isVerticallyCentered =
            false

        let operation =
            NSPrintOperation(
                view:
                    printableView,
                printInfo:
                    printInfo
            )

        operation.showsPrintPanel =
            true

        operation.showsProgressPanel =
            true

        operation.run()
    }


    private static func captureScrollableContent(
        scrollView:
            NSScrollView,
        rootView:
            NSView,
        window:
            NSWindow
    ) -> NSView?
    {
        guard
            let documentView =
                scrollView.documentView
        else {
            return nil
        }

        let clipView =
            scrollView.contentView

        scrollView.layoutSubtreeIfNeeded()
        documentView.layoutSubtreeIfNeeded()

        let viewportHeight =
            clipView.bounds.height

        let contentHeight =
            documentView.bounds.height

        guard
            viewportHeight > 1,
            contentHeight > 1
        else {
            return nil
        }

        let originalOrigin =
            clipView.bounds.origin

        let maximumStart =
            max(
                0,
                contentHeight
                - viewportHeight
            )

        var starts:
            [CGFloat] = [
                0
            ]

        if maximumStart > 0 {
            var position =
                viewportHeight

            while
                position
                < maximumStart - 0.5
            {
                starts.append(
                    position
                )

                position +=
                    viewportHeight
            }

            if
                abs(
                    (starts.last ?? 0)
                    - maximumStart
                ) > 0.5
            {
                starts.append(
                    maximumStart
                )
            }
        }

        var chunks:
            [CapturedChunk] = []

        var printableWidth:
            CGFloat = 0

        defer {
            clipView.scroll(
                to:
                    originalOrigin
            )

            scrollView.reflectScrolledClipView(
                clipView
            )

            window.displayIfNeeded()
        }

        for index in
            starts.indices
        {
            let visualStart =
                starts[
                    index
                ]

            let nextStart:
                CGFloat

            if
                index + 1
                < starts.count
            {
                nextStart =
                    starts[
                        index + 1
                    ]

            } else {
                nextStart =
                    contentHeight
            }

            let segmentHeight =
                max(
                    1,
                    min(
                        viewportHeight,
                        nextStart
                        - visualStart
                    )
                )

            let targetY:
                CGFloat

            if documentView.isFlipped {
                targetY =
                    documentView.bounds.minY
                    + visualStart

            } else {
                targetY =
                    documentView.bounds.maxY
                    - viewportHeight
                    - visualStart
            }

            clipView.scroll(
                to:
                    NSPoint(
                        x:
                            originalOrigin.x,
                        y:
                            targetY
                    )
            )

            scrollView.reflectScrolledClipView(
                clipView
            )

            documentView.layoutSubtreeIfNeeded()
            scrollView.layoutSubtreeIfNeeded()
            rootView.layoutSubtreeIfNeeded()

            window.displayIfNeeded()

            RunLoop.current.run(
                until:
                    Date()
                        .addingTimeInterval(
                            0.015
                        )
            )

            window.displayIfNeeded()

            let fullVisibleRect =
                rootView.convert(
                    clipView.bounds,
                    from:
                        clipView
                )
                .intersection(
                    rootView.bounds
                )

            guard
                fullVisibleRect.width > 1,
                fullVisibleRect.height > 1
            else {
                return nil
            }

            printableWidth =
                fullVisibleRect.width

            let actualSegmentHeight =
                min(
                    segmentHeight,
                    fullVisibleRect.height
                )

            let captureRect:
                NSRect

            if rootView.isFlipped {
                captureRect =
                    NSRect(
                        x:
                            fullVisibleRect.minX,
                        y:
                            fullVisibleRect.minY,
                        width:
                            fullVisibleRect.width,
                        height:
                            actualSegmentHeight
                    )

            } else {
                captureRect =
                    NSRect(
                        x:
                            fullVisibleRect.minX,
                        y:
                            fullVisibleRect.maxY
                            - actualSegmentHeight,
                        width:
                            fullVisibleRect.width,
                        height:
                            actualSegmentHeight
                    )
            }

            guard
                let image =
                    renderedImage(
                        of:
                            rootView,
                        rect:
                            captureRect
                    )
            else {
                return nil
            }

            chunks.append(
                CapturedChunk(
                    image:
                        image,
                    y:
                        visualStart,
                    height:
                        actualSegmentHeight
                )
            )
        }

        guard
            printableWidth > 1,
            !chunks.isEmpty
        else {
            return nil
        }

        return
            TestudoPrintableContentView(
                frame:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            printableWidth,
                        height:
                            contentHeight
                    ),
                chunks:
                    chunks
            )
    }


    private static func captureVisibleDetail(
        detailView:
            NSView,
        rootView:
            NSView,
        window:
            NSWindow
    ) -> NSView?
    {
        window.displayIfNeeded()

        let rect =
            rootView.convert(
                detailView.bounds,
                from:
                    detailView
            )
            .intersection(
                rootView.bounds
            )

        guard
            rect.width > 1,
            rect.height > 1,
            let image =
                renderedImage(
                    of:
                        rootView,
                    rect:
                        rect
                )
        else {
            return nil
        }

        let chunk =
            CapturedChunk(
                image:
                    image,
                y:
                    0,
                height:
                    rect.height
            )

        return
            TestudoPrintableContentView(
                frame:
                    NSRect(
                        origin:
                            .zero,
                        size:
                            rect.size
                    ),
                chunks:
                    [
                        chunk
                    ]
            )
    }


    private static func renderedImage(
        of sourceView:
            NSView,
        rect:
            NSRect
    ) -> NSImage?
    {
        guard
            let bitmap =
                sourceView
                    .bitmapImageRepForCachingDisplay(
                        in:
                            rect
                    )
        else {
            return nil
        }

        sourceView.cacheDisplay(
            in:
                rect,
            to:
                bitmap
        )

        bitmap.size =
            rect.size

        let image =
            NSImage(
                size:
                    rect.size
            )

        image.addRepresentation(
            bitmap
        )

        return image
    }


    private static func printableScrollView(
        in detailView:
            NSView
    ) -> NSScrollView?
    {
        allScrollViews(
            in:
                detailView
        )
        .filter {
            scrollView in

            guard
                !scrollView.isHidden,
                let documentView =
                    scrollView.documentView
            else {
                return false
            }

            return
                scrollView.contentView.bounds.width > 1
                && scrollView.contentView.bounds.height > 1
                && documentView.bounds.width > 1
                && documentView.bounds.height > 1
        }
        .max(
            by: {
                lhs,
                rhs in

                scrollScore(
                    lhs
                )
                <
                scrollScore(
                    rhs
                )
            }
        )
    }


    private static func scrollScore(
        _ scrollView:
            NSScrollView
    ) -> CGFloat
    {
        guard
            let documentView =
                scrollView.documentView
        else {
            return 0
        }

        let overflow =
            max(
                0,
                documentView.bounds.height
                - scrollView.contentView.bounds.height
            )

        return
            overflow * 10000
            + documentView.bounds.height
    }


    private static func detailPane(
        in rootView:
            NSView
    ) -> NSView?
    {
        let candidates =
            allSplitViews(
                in:
                    rootView
            )
            .filter {
                splitView in

                visiblePanes(
                    in:
                        splitView
                )
                .count >= 2
            }

        guard
            let mainSplitView =
                candidates.max(
                    by: {
                        lhs,
                        rhs in

                        area(
                            of:
                                lhs
                        )
                        <
                        area(
                            of:
                                rhs
                        )
                    }
                )
        else {
            return nil
        }

        return
            visiblePanes(
                in:
                    mainSplitView
            )
            .max(
                by: {
                    lhs,
                    rhs in

                    lhs.frame.maxX
                    <
                    rhs.frame.maxX
                }
            )
    }


    private static func allSplitViews(
        in rootView:
            NSView
    ) -> [NSSplitView]
    {
        var result:
            [NSSplitView] = []

        if
            let splitView =
                rootView
                as? NSSplitView
        {
            result.append(
                splitView
            )
        }

        for subview in
            rootView.subviews
        {
            result.append(
                contentsOf:
                    allSplitViews(
                        in:
                            subview
                    )
            )
        }

        return result
    }


    private static func allScrollViews(
        in rootView:
            NSView
    ) -> [NSScrollView]
    {
        var result:
            [NSScrollView] = []

        if
            let scrollView =
                rootView
                as? NSScrollView
        {
            result.append(
                scrollView
            )
        }

        for subview in
            rootView.subviews
        {
            result.append(
                contentsOf:
                    allScrollViews(
                        in:
                            subview
                    )
            )
        }

        return result
    }


    private static func visiblePanes(
        in splitView:
            NSSplitView
    ) -> [NSView]
    {
        splitView
            .subviews
            .filter {
                view in

                !view.isHidden
                && view.frame.width > 1
                && view.frame.height > 1
            }
    }


    private static func area(
        of view:
            NSView
    ) -> CGFloat
    {
        view.bounds.width
        * view.bounds.height
    }


    private final class TestudoPrintableContentView:
        NSView
    {
        private let chunks:
            [CapturedChunk]


        init(
            frame:
                NSRect,
            chunks:
                [CapturedChunk]
        )
        {
            self.chunks =
                chunks

            super.init(
                frame:
                    frame
            )
        }


        required init?(
            coder:
                NSCoder
        )
        {
            nil
        }


        override var isFlipped:
            Bool
        {
            true
        }


        override func draw(
            _ dirtyRect:
                NSRect
        )
        {
            super.draw(
                dirtyRect
            )

            NSColor.white.setFill()

            dirtyRect.fill()

            for chunk in
                chunks
            {
                let destination =
                    NSRect(
                        x:
                            0,
                        y:
                            chunk.y,
                        width:
                            bounds.width,
                        height:
                            chunk.height
                    )

                guard
                    destination
                        .intersects(
                            dirtyRect
                        )
                else {
                    continue
                }

                chunk.image.draw(
                    in:
                        destination,
                    from:
                        NSRect(
                            origin:
                                .zero,
                            size:
                                chunk.image.size
                        ),
                    operation:
                        .sourceOver,
                    fraction:
                        1,
                    respectFlipped:
                        true,
                    hints:
                        nil
                )
            }
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
