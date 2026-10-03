import SwiftUI
import Foundation
import AppKit

enum SidebarSection:
    String,
    CaseIterable,
    Identifiable
{
    case newEntry
    case today
    case calendar
    case allTasks
    case todo
    case inProgress
    case completed
    case archive
    case timeline
    case themes
    case organizations
    case groups
    case people

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .newEntry:
            return "New Entry"

        case .today:
            return "Today"
        case .calendar:
            return "Calendar"
        case .allTasks:
            return "All Tasks"
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .archive:
            return "Archive"
        case .timeline:
            return "Timeline"
        case .themes:
            return "Themes"
        case .organizations:
            return "Organizations"
        case .groups:
            return "Groups"
        case .people:
            return "People"
        }
    }

    var icon: String {
        switch self {
        case .newEntry:
            return "square.and.pencil"

        case .today:
            return "calendar"
        case .calendar:
            return "calendar.badge.clock"
        case .allTasks:
            return "list.bullet.indent"
        case .todo:
            return "circle"
        case .inProgress:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .archive:
            return "archivebox"
        case .timeline:
            return "list.bullet.rectangle"
        case .themes:
            return "square.stack.3d.up"
        case .organizations:
            return "building.2"
        case .groups:
            return "person.3"
        case .people:
            return "person.2"
        }
    }
}

private struct DetailTrackpadNavigationCapture:
    NSViewRepresentable
{
    let onBack: () -> Void
    let onForward: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBack: onBack,
            onForward: onForward
        )
    }

    func makeNSView(
        context: Context
    ) -> NSView {
        let view = NSView()

        context.coordinator.hostView =
            view

        context.coordinator.install()

        return view
    }

    func updateNSView(
        _ nsView: NSView,
        context: Context
    ) {
        context.coordinator.hostView =
            nsView

        context.coordinator.onBack =
            onBack

        context.coordinator.onForward =
            onForward
    }

    static func dismantleNSView(
        _ nsView: NSView,
        coordinator: Coordinator
    ) {
        coordinator.uninstall()
    }

    final class Coordinator {
        weak var hostView: NSView?

        var onBack: () -> Void
        var onForward: () -> Void

        private var monitor:
            Any?

        private var accumulatedX:
            CGFloat = 0

        private var gestureTriggered =
            false
        init(
            onBack: @escaping () -> Void,
            onForward: @escaping () -> Void
        ) {
            self.onBack =
                onBack

            self.onForward =
                onForward
        }

        func install() {
            guard monitor == nil
            else {
                return
            }

            monitor =
                NSEvent
                    .addLocalMonitorForEvents(
                        matching:
                            .scrollWheel
                    ) {
                        [weak self]
                        event in

                        nonisolated(unsafe) let eventForMainActor = event
                        nonisolated(unsafe) weak var handlerForMainActor = self

                        MainActor.assumeIsolated {
                            handlerForMainActor?.handle(
                                eventForMainActor
                            )
                        }

                        // Never swallow the event.
                        // Vertical scrolling remains native.
                        return event
                    }
        }

        func uninstall() {
            if let monitor {
                NSEvent
                    .removeMonitor(
                        monitor
                    )

                self.monitor =
                    nil
            }
        }

        @MainActor
        private func handle(
            _ event: NSEvent
        ) {
            guard
                event.hasPreciseScrollingDeltas,
                let hostView,
                let window =
                    hostView.window,
                event.window === window
            else {
                return
            }

            let point =
                hostView.convert(
                    event.locationInWindow,
                    from: nil
                )

            guard
                hostView.bounds
                    .contains(point)
            else {
                return
            }

            /*
             One physical gesture = one navigation step.

             Momentum events are deliberately ignored. The latch is
             reset ONLY when macOS reports the beginning of a genuinely
             new two-finger gesture.

             This prevents a long swipe or its momentum from moving
             through several history entries.
            */
            if event.phase == .began {
                resetGesture()
            }

            guard
                event.phase == .began
                    || event.phase == .changed
            else {
                return
            }

            guard !gestureTriggered
            else {
                return
            }

            var dx =
                event.scrollingDeltaX

            let dy =
                event.scrollingDeltaY

            if
                event
                    .isDirectionInvertedFromDevice
            {
                dx = -dx
            }

            guard
                abs(dx) > 0.8,
                abs(dx)
                    > abs(dy) * 1.35
            else {
                return
            }

            accumulatedX += dx

            let threshold:
                CGFloat = 52

            if accumulatedX >= threshold {
                gestureTriggered =
                    true

                onForward()

            } else if
                accumulatedX
                    <= -threshold
            {
                gestureTriggered =
                    true

                onBack()
            }
        }

        private func resetGesture() {
            accumulatedX = 0
            gestureTriggered = false
        }

        deinit {
            uninstall()
        }
    }
}

struct WorkCreationRequest:
    Identifiable,
    Equatable
{
    let id =
        UUID()

    let initialKind:
        WorkItemKind

    let themeID:
        UUID?

    let parentWorkItemID:
        UUID?
}


private enum DetailNavigationEntry:
    Equatable
{
    case work(
        section: SidebarSection,
        id: UUID
    )

    case theme(
        id: UUID
    )

    case organization(
        id: UUID
    )

    case group(
        id: UUID
    )

    case person(
        id: UUID
    )


    case calendarEvent(
        id: UUID
    )
}

struct ContentView: View {
    @State
    private var selection:
        SidebarSection? = .today

    @State
    private var columnVisibility:
        NavigationSplitViewVisibility =
        .all

    @State
    private var selectedThemeID:
        UUID?

    @State
    private var selectedOrganizationID:
        UUID?

    @State
    private var selectedGroupID:
        UUID?

    @State
    private var selectedPersonID:
        UUID?

    @State
    private var selectedWorkItemID:
        UUID?


    @State
    private var selectedCalendarEventID:
        UUID?

    @State
    private var calendarEventCreationRequest:
        CalendarEventCreationRequest?

    @State
    private var workCreationRequest:
        WorkCreationRequest?

    @State
    private var detailBackStack:
        [DetailNavigationEntry] = []

    @State
    private var detailForwardStack:
        [DetailNavigationEntry] = []

    @State
    private var currentDetailEntry:
        DetailNavigationEntry?

    var body: some View {
        NavigationSplitView(
            columnVisibility:
                $columnVisibility
        ) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Button {
                        selection =
                            .newEntry

                        workCreationRequest =
                            WorkCreationRequest(
                                initialKind:
                                    .task,
                                themeID:
                                    nil,
                                parentWorkItemID:
                                    nil
                            )
                    } label: {
                        HStack(
                            spacing:
                                8
                        ) {
                            Image(
                                systemName:
                                    "square.and.pencil"
                            )
                            .frame(
                                width:
                                    18,
                                alignment:
                                    .center
                            )

                            Text(
                                "New entry"
                            )
                            .lineLimit(
                                1
                            )
                            .layoutPriority(
                                1
                            )

                            Spacer(
                                minLength:
                                    0
                            )
                        }
                        .fontWeight(
                            .medium
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(
                        SidebarSection.newEntry
                    )
                    .padding(
                        .vertical,
                        3
                    )
                    .help("New Work Entry")
                    .keyboardShortcut(
                        "n",
                        modifiers:
                            .command
                    )

                    Section {
                        sidebarRow(
                            .today
                        )

                        sidebarRow(
                            .calendar
                        )

                        sidebarRow(
                            .allTasks
                        )

                        sidebarRow(
                            .todo
                        )

                        sidebarRow(
                            .inProgress
                        )

                        sidebarRow(
                            .completed
                        )

                        sidebarRow(
                            .archive
                        )

                        sidebarRow(
                            .timeline
                        )
                    } header: {
                        HStack(
                            spacing: 6
                        ) {
                            Text("Work")

                            Spacer()

                        }
                    }

                    Section("Structure") {
                        sidebarRow(
                            .themes
                        )

                        sidebarRow(
                            .organizations
                        )

                        sidebarRow(
                            .groups
                        )

                        sidebarRow(
                            .people
                        )
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)

                SidebarUserFooter()
            }
            .background(.regularMaterial)
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 220,
                max: 280
            )
        } content: {
            SectionContentView(
                section:
                    selection ?? .today,
                selectedThemeID:
                    $selectedThemeID,
                selectedOrganizationID:
                    $selectedOrganizationID,
                selectedGroupID:
                    $selectedGroupID,
                selectedPersonID:
                    $selectedPersonID,
                selectedWorkItemID:
                    $selectedWorkItemID,
                selectedCalendarEventID:
                    $selectedCalendarEventID,
                calendarEventCreationRequest:
                    $calendarEventCreationRequest,
                workCreationRequest:
                    $workCreationRequest
            )
            .padding(
                .top,
                middleColumnTopPadding
            )
            .background(
                TestudoStyle.contentBackground
            )
            .ignoresSafeArea(
                .container,
                edges: .top
            )
            .navigationSplitViewColumnWidth(
                min: 330,
                ideal: 390,
                max: 560
            )
        } detail: {
            VStack(
                spacing: 0
            ) {
                detailNavigationBar

                WorkDetailRouterView(
                    section:
                        selection ?? .today,
                    selectedThemeID:
                        $selectedThemeID,
                    selectedOrganizationID:
                        $selectedOrganizationID,
                    selectedGroupID:
                        $selectedGroupID,
                    selectedWorkItemID:
                        $selectedWorkItemID,
                    selectedCalendarEventID:
                        $selectedCalendarEventID,
                    selectedPersonID:
                        $selectedPersonID,
                    calendarEventCreationRequest:
                        $calendarEventCreationRequest,
                    workCreationRequest:
                        $workCreationRequest
                )
                .environment(
                    \.testudoDetailNavigation,
                    TestudoDetailNavigationAction {
                        destination in

                        navigateFromDetail(
                            destination
                        )
                    }
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .padding(.top, 12)
            .background(
                TestudoStyle.contentBackground
            )
            .background {
                DetailTrackpadNavigationCapture(
                    onBack:
                        navigateDetailBack,
                    onForward:
                        navigateDetailForward
                )
            }
            .ignoresSafeArea(
                .container,
                edges: .top
            )
            .navigationSplitViewColumnWidth(
                min: 420,
                ideal: 650
            )
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(
            of: selectedWorkItemID
        ) {
            _,
            newValue in

            registerWorkSelection(
                newValue
            )
        }
        .onChange(
            of: selectedCalendarEventID
        ) {
            _,
            newValue in

            registerCalendarEventSelection(
                newValue
            )
        }
        .onChange(
            of: selectedThemeID
        ) {
            _,
            newValue in

            registerThemeSelection(
                newValue
            )
        }
        .onChange(
            of: selectedOrganizationID
        ) {
            _,
            newValue in

            registerOrganizationSelection(
                newValue
            )
        }
        .onChange(
            of: selectedGroupID
        ) {
            _,
            newValue in

            registerGroupSelection(
                newValue
            )
        }
        .onChange(
            of: selectedPersonID
        ) {
            _,
            newValue in

            registerPersonSelection(
                newValue
            )
        }
        .onChange(
            of: selection
        ) {
            _,
            newValue in

            sectionDidChange(
                newValue
            )
        }
    }

    private var middleColumnTopPadding:
        CGFloat
    {
        if columnVisibility == .doubleColumn {
            return 38
        }

        if columnVisibility == .all {
            return 20
        }

        return 12
    }


    // ========================================================
    // Browser-style detail navigation
    // ========================================================

    private var workSidebarSections:
        [SidebarSection]
    {
        [
            .today,
            .calendar,
            .allTasks,
            .todo,
            .inProgress,
            .completed,
            .archive,
            .timeline
        ]
    }

    private var structureSidebarSections:
        [SidebarSection]
    {
        [
            .themes,
            .organizations,
            .groups,
            .people
        ]
    }

    @ViewBuilder
    private func sidebarRow(
        _ item: SidebarSection
    ) -> some View {
        HStack(
            spacing:
                8
        ) {
            Image(
                systemName:
                    item.icon
            )
            .frame(
                width:
                    18,
                alignment:
                    .center
            )

            Text(
                item.title
            )
            .lineLimit(
                1
            )
            .layoutPriority(
                1
            )

            Spacer(
                minLength:
                    0
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
        .contentShape(
            Rectangle()
        )
        .tag(
            item
        )
        .padding(
            .vertical,
            1
        )
    }


    private var detailNavigationBar:
        some View
    {
        HStack(
            spacing: 4
        ) {
            Button(
                action:
                    navigateDetailBack
            ) {
                Image(
                    systemName:
                        "chevron.left"
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .semibold
                    )
                )
                .frame(
                    width: 26,
                    height: 26
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(.plain)
            .disabled(
                detailBackStack
                    .isEmpty
            )
            .help("Back")

            Button(
                action:
                    navigateDetailForward
            ) {
                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .system(
                        size: 12,
                        weight:
                            .semibold
                    )
                )
                .frame(
                    width: 26,
                    height: 26
                )
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(.plain)
            .disabled(
                detailForwardStack
                    .isEmpty
            )
            .help("Forward")

            Spacer()

        }
        .padding(
            .leading,
            8
        )
        .padding(
            .trailing,
            10
        )
        .padding(
            .top,
            2
        )
        .padding(
            .bottom,
            2
        )
        .frame(
            minHeight: 30
        )
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private func registerWorkSelection(
        _ id: UUID?
    ) {
        if
            let id,
            selection == .newEntry
        {
            workCreationRequest =
                nil

            selection =
                .allTasks

            registerDetailNavigation(
                .work(
                    section:
                        .allTasks,
                    id:
                        id
                )
            )

            return
        }

        guard
            let id,
            let section =
                selection,
            (
                isWorkSection(
                    section
                )
                || section == .themes
            )
        else {
            return
        }

        workCreationRequest =
            nil

        if section == .themes {
            selectedThemeID =
                nil
        }

        registerDetailNavigation(
            .work(
                section:
                    section,
                id:
                    id
            )
        )
    }

    private func registerCalendarEventSelection(
        _ id: UUID?
    ) {
        guard
            let id,
            selection == .calendar
        else {
            return
        }

        workCreationRequest =
            nil

        calendarEventCreationRequest =
            nil

        selectedWorkItemID =
            nil

        registerDetailNavigation(
            .calendarEvent(
                id: id
            )
        )
    }


    private func registerThemeSelection(
        _ id: UUID?
    ) {
        guard
            let id,
            selection == .themes
        else {
            return
        }

        workCreationRequest =
            nil

        selectedWorkItemID =
            nil

        registerDetailNavigation(
            .theme(
                id: id
            )
        )
    }

    private func registerOrganizationSelection(
        _ id: UUID?
    ) {
        guard
            let id,
            selection == .organizations
        else {
            return
        }

        workCreationRequest =
            nil

        selectedWorkItemID =
            nil

        registerDetailNavigation(
            .organization(
                id: id
            )
        )
    }

    private func registerGroupSelection(
        _ id: UUID?
    ) {
        guard
            let id,
            selection == .groups
        else {
            return
        }

        workCreationRequest =
            nil

        selectedWorkItemID =
            nil

        registerDetailNavigation(
            .group(
                id: id
            )
        )
    }

    private func registerPersonSelection(
        _ id: UUID?
    ) {
        guard
            let id,
            selection == .people
        else {
            return
        }

        workCreationRequest =
            nil

        selectedWorkItemID =
            nil

        registerDetailNavigation(
            .person(
                id: id
            )
        )
    }

    private func sectionDidChange(
        _ newSection:
            SidebarSection?
    ) {
        guard let newSection
        else {
            return
        }

        if newSection != .newEntry {
            workCreationRequest =
                nil
        }

        if newSection == .newEntry {
            return
        }

        // Moving between Work filters does not create a
        // new browser-history entry when the right pane
        // still shows exactly the same object. We merely
        // update the section context of the current entry.
        if
            isWorkSection(
                newSection
            ),
            let selectedWorkItemID
        {
            let newEntry =
                DetailNavigationEntry
                    .work(
                        section:
                            newSection,
                        id:
                            selectedWorkItemID
                    )

            if
                case
                    .work(
                        _,
                        let currentID
                    )? =
                    currentDetailEntry,
                currentID
                    == selectedWorkItemID
            {
                currentDetailEntry =
                    newEntry
            } else {
                registerDetailNavigation(
                    newEntry
                )
            }

            return
        }

        if
            newSection == .themes,
            let selectedThemeID
        {
            registerDetailNavigation(
                .theme(
                    id:
                        selectedThemeID
                )
            )

            return
        }

        if
            newSection == .organizations,
            let selectedOrganizationID
        {
            registerDetailNavigation(
                .organization(
                    id:
                        selectedOrganizationID
                )
            )

            return
        }

        if
            newSection == .groups,
            let selectedGroupID
        {
            registerDetailNavigation(
                .group(
                    id:
                        selectedGroupID
                )
            )

            return
        }

        if
            newSection == .people,
            let selectedPersonID
        {
            registerDetailNavigation(
                .person(
                    id:
                        selectedPersonID
                )
            )
        }
    }

    private func registerDetailNavigation(
        _ entry:
            DetailNavigationEntry
    ) {
        guard
            currentDetailEntry
                != entry
        else {
            return
        }

        if
            let current =
                currentDetailEntry
        {
            detailBackStack
                .append(
                    current
                )

            if
                detailBackStack
                    .count
                    > 100
            {
                detailBackStack
                    .removeFirst(
                        detailBackStack
                            .count
                        - 100
                    )
            }
        }

        currentDetailEntry =
            entry

        // Browser semantics:
        // choosing a new destination after Back
        // discards the Forward branch.
        detailForwardStack
            .removeAll()
    }

    private func navigateDetailBack() {
        guard
            let destination =
                detailBackStack
                    .popLast()
        else {
            return
        }

        if
            let current =
                currentDetailEntry
        {
            detailForwardStack
                .append(
                    current
                )
        }

        currentDetailEntry =
            destination

        applyDetailNavigation(
            destination
        )
    }

    private func navigateDetailForward() {
        guard
            let destination =
                detailForwardStack
                    .popLast()
        else {
            return
        }

        if
            let current =
                currentDetailEntry
        {
            detailBackStack
                .append(
                    current
                )
        }

        currentDetailEntry =
            destination

        applyDetailNavigation(
            destination
        )
    }

    private func navigateFromDetail(
        _ destination:
            TestudoDetailDestination
    ) {
        let entry:
            DetailNavigationEntry

        switch destination {

        case .work(
            let id
        ):
            entry =
                .work(
                    section:
                        .allTasks,
                    id:
                        id
                )

        case .theme(
            let id
        ):
            entry =
                .theme(
                    id:
                        id
                )

        case .organization(
            let id
        ):
            entry =
                .organization(
                    id:
                        id
                )

        case .group(
            let id
        ):
            entry =
                .group(
                    id:
                        id
                )

        case .person(
            let id
        ):
            entry =
                .person(
                    id:
                        id
                )
        }


        registerDetailNavigation(
            entry
        )

        applyDetailNavigation(
            entry
        )
    }


    private func applyDetailNavigation(
        _ entry:
            DetailNavigationEntry
    ) {
        switch entry {
        case
            .work(
                let section,
                let id
            ):

            workCreationRequest =
                nil

            selection =
                section

            selectedWorkItemID =
                id

        case
            .calendarEvent(
                let id
            ):

            workCreationRequest =
                nil

            calendarEventCreationRequest =
                nil

            selectedWorkItemID =
                nil

            selectedCalendarEventID =
                id

            selection =
                .calendar

        case
            .theme(
                let id
            ):

            workCreationRequest =
                nil

            selectedWorkItemID =
                nil

            selectedThemeID =
                id

            selection =
                .themes

        case
            .organization(
                let id
            ):

            workCreationRequest =
                nil

            selectedWorkItemID =
                nil

            selectedOrganizationID =
                id

            selection =
                .organizations

        case
            .group(
                let id
            ):

            workCreationRequest =
                nil

            selectedWorkItemID =
                nil

            selectedGroupID =
                id

            selection =
                .groups

        case
            .person(
                let id
            ):

            workCreationRequest =
                nil

            selectedWorkItemID =
                nil

            selectedPersonID =
                id

            selection =
                .people
        }
    }

    private func isWorkSection(
        _ section:
            SidebarSection
    ) -> Bool {
        switch section {
        case .today,
             .calendar,
             .allTasks,
             .todo,
             .inProgress,
             .completed,
             .archive,
             .timeline:
            return true

        case .newEntry,
             .themes,
             .organizations,
             .groups,
             .people:
            return false
        }
    }
}

private struct SectionContentView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let section: SidebarSection

    @Binding
    var selectedThemeID: UUID?

    @Binding
    var selectedOrganizationID: UUID?

    @Binding
    var selectedGroupID: UUID?

    @Binding
    var selectedPersonID: UUID?

    @Binding
    var selectedWorkItemID: UUID?

    @Binding
    var selectedCalendarEventID: UUID?

    @Binding
    var calendarEventCreationRequest:
        CalendarEventCreationRequest?

    @Binding
    var workCreationRequest:
        WorkCreationRequest?

    @State
    private var showingCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if showsOuterHeader {
                HStack(spacing: 12) {
                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {
                    Text(section.title)
                        .font(
                            .system(
                                size: 15,
                                weight: .semibold
                            )
                        )

                    Text(sectionSummary)
                        .font(.caption)
                        .foregroundStyle(
                            TestudoStyle.secondaryText
                        )
                }

                Spacer()

                if canCreate {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(
                            systemName:
                                "square.and.pencil"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .medium
                            )
                        )
                        .frame(
                            width: 28,
                            height: 28
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(.plain)
                    .help("New")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.top, 2)
            .padding(.bottom, 3)
            .frame(minHeight: 36)
            .background(
                TestudoStyle.headerBackground
            )

                Divider()
            }

            sectionBody
                .background(
                    TestudoStyle.contentBackground
                )
        }
        .sheet(
            isPresented:
                $showingCreateSheet
        ) {
            createSheet
        }
    }

    private var showsOuterHeader: Bool {
        switch section {
        case .newEntry,
             .today,
             .calendar,
             .allTasks,
             .todo,
             .inProgress,
             .completed,
             .archive,
             .timeline:
            return false

        case .themes,
             .organizations,
             .groups,
             .people:
            return true
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
        case .newEntry:
            WorkListView(
                mode:
                    .all,
                selection:
                    $selectedWorkItemID
            )

        case .today:
            TodayDashboardView(
                selection:
                    $selectedWorkItemID
            )
        case .calendar:
            WorkCalendarView(
                selectedWorkItemID:
                    $selectedWorkItemID,
                selectedCalendarEventID:
                    $selectedCalendarEventID,
                calendarEventCreationRequest:
                    $calendarEventCreationRequest
            )

        case .allTasks:
            WorkListView(
                mode: .all,
                selection:
                    $selectedWorkItemID
            )
        case .todo:
            WorkListView(
                mode: .todo,
                selection:
                    $selectedWorkItemID
            )
        case .inProgress:
            WorkListView(
                mode: .inProgress,
                selection:
                    $selectedWorkItemID
            )
        case .completed:
            WorkListView(
                mode: .completed,
                selection:
                    $selectedWorkItemID
            )
        case .archive:
            ArchiveWorkListView(
                selection:
                    $selectedWorkItemID
            )

        case .timeline:
            WorkListView(
                mode: .timeline,
                selection:
                    $selectedWorkItemID
            )
        case .themes:
            ThemeListView(
                selection:
                    $selectedThemeID,
                selectedWorkItemID:
                    $selectedWorkItemID,
                workCreationRequest:
                    $workCreationRequest
            )

        case .organizations:
            EntityListView(
                kind: .organization,
                selection:
                    $selectedOrganizationID
            )

        case .groups:
            EntityListView(
                kind: .group,
                selection:
                    $selectedGroupID
            )

        case .people:
            PeopleListView(
                selection:
                    $selectedPersonID
            )
        }
    }

    @ViewBuilder
    private var createSheet: some View {
        switch section {
        case .themes:
            CreateThemeView(
                isPresented:
                    $showingCreateSheet
            )

        case .organizations:
            CreateEntityView(
                kind: .organization,
                isPresented:
                    $showingCreateSheet
            )

        case .groups:
            CreateEntityView(
                kind: .group,
                isPresented:
                    $showingCreateSheet
            )

        case .people:
            CreateEntityView(
                kind: .person,
                isPresented:
                    $showingCreateSheet
            )

        default:
            EmptyView()
        }
    }

    private var canCreate: Bool {
        switch section {
        case .themes,
             .organizations,
             .groups,
             .people:
            return true

        default:
            return false
        }
    }

    private var sectionSummary: String {
        switch section.rawValue {
        case "today":
            let count =
                store.todayWorkItems().count

            return count == 1
                ? "1 item today"
                : "\(count) items today"

        case "allTasks":
            let count =
                store.data.workItems
                    .filter {
                        $0.kind == .task
                    }
                    .count

            return count == 1
                ? "1 task"
                : "\(count) tasks"

        case "todo":
            let count =
                store.tasks(
                    with: .todo
                ).count

            return count == 1
                ? "1 task"
                : "\(count) tasks"

        case "inProgress":
            let count =
                store.tasks(
                    with: .inProgress
                ).count

            return count == 1
                ? "1 task"
                : "\(count) tasks"

        case "completed":
            let count =
                store.tasks(
                    with: .completed
                ).count

            return count == 1
                ? "1 task"
                : "\(count) tasks"

        case "timeline":
            let count =
                store.data.historyEvents.count

            return count == 1
                ? "1 event"
                : "\(count) events"

        case "themes":
            let count =
                store.data.themes.count

            return count == 1
                ? "1 theme"
                : "\(count) themes"

        case "organizations":
            let count =
                store.entities(
                    of: .organization
                ).count

            return count == 1
                ? "1 organization"
                : "\(count) organizations"

        case "groups":
            let count =
                store.entities(
                    of: .group
                ).count

            return count == 1
                ? "1 group"
                : "\(count) groups"

        case "people":
            let count =
                store.entities(
                    of: .person
                ).count

            return count == 1
                ? "1 person"
                : "\(count) people"

        default:
            return subtitle
        }
    }

    private var subtitle: String {
        switch section {
        case .newEntry:
            return
                "Create a new work entry"

        case .calendar:
            return "Deadlines and reminders"

        case .today:
            return
                "Work and activity recorded today"

        case .allTasks:
            return
                "Complete task hierarchy across all statuses"

        case .todo:
            return
                "Tasks waiting to be started"

        case .inProgress:
            return
                "Work currently in progress"

        case .completed:
            return
                "Completed work"

        case .archive:
            return
                "Closed work retained for history and reporting"

        case .timeline:
            return
                "Chronological history of your work"

        case .themes:
            return
                "Themes, tasks, notes and activity"

        case .organizations:
            return
                "Organizations and sub-organizations"

        case .groups:
            return
                "Groups inside or outside organizations"

        case .people:
            return
                "People and their affiliations"
        }
    }
}

private struct ThemeListView: View {
    @EnvironmentObject
    private var store: TestudoStore

    @Binding
    var selection: UUID?

    @Binding
    var selectedWorkItemID:
        UUID?

    @Binding
    var workCreationRequest:
        WorkCreationRequest?


    var body: some View {
        let roots =
            store.childThemes(of: nil)

        if roots.isEmpty {
            ContentUnavailableView {
                Label(
                    "No Themes Yet",
                    systemImage:
                        "square.stack.3d.up"
                )
            } description: {
                Text(
                    "Create a theme to begin organizing your work."
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List {
                ForEach(roots) { theme in
                    ThemeNodeView(
                        theme: theme,
                        selection:
                            $selection,
                        selectedWorkItemID:
                            $selectedWorkItemID,
                        workCreationRequest:
                            $workCreationRequest
                    )
                }
            }
        }
    }
}

private struct ThemeNodeView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let theme: Theme

    @Binding
    var selection: UUID?

    @Binding
    var selectedWorkItemID:
        UUID?

    @Binding
    var workCreationRequest:
        WorkCreationRequest?

    @State
    private var isExpanded = true

    @State
    private var createKind:
        WorkItemKind?

    @State
    private var showingCreateSubtheme =
        false

    private var hierarchyDepth:
        Int
    {
        var depth =
            0

        var currentParentID =
            theme.parentThemeID

        var visited =
            Set<UUID>()

        while
            let parentID =
                currentParentID,
            visited
                .insert(
                    parentID
                )
                .inserted,
            let parent =
                store.theme(
                    id:
                        parentID
                )
        {
            depth +=
                1

            currentParentID =
                parent.parentThemeID
        }

        return depth
    }


    private var isSelectedTheme:
        Bool
    {
        selection
            == theme.id
        &&
        selectedWorkItemID
            == nil
    }


    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded
        ) {
            ForEach(
                store.rootWorkItems(
                    for: theme.id
                )
            ) { item in
                WorkItemNodeView(
                    item: item,
                    selectedWorkItemID:
                        $selectedWorkItemID,
                    workCreationRequest:
                        $workCreationRequest,
                    initiallyExpanded:
                        false
                )
            }

            ForEach(
                store.childThemes(
                    of: theme.id
                )
            ) { child in
                ThemeNodeView(
                    theme: child,
                    selection:
                        $selection,
                    selectedWorkItemID:
                        $selectedWorkItemID,
                    workCreationRequest:
                        $workCreationRequest
                )
            }
        } label: {
            HStack {
                Label(
                    theme.name,
                    systemImage: "folder"
                )
                .fontWeight(.medium)

                Spacer()

                Menu {
                    Button(
                        "New Sub-theme"
                    ) {
                        showingCreateSubtheme =
                            true
                    }

                    Divider()

                    Button("New Task") {
                        createKind = .task
                    }

                    Button("New Note") {
                        createKind = .note
                    }

                    Button("New Activity") {
                        createKind = .activity
                    }
                } label: {
                    Image(
                        systemName:
                            "plus.circle"
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(
                .leading,
                CGFloat(
                    hierarchyDepth
                )
                * 10
            )
            .frame(
                height: 46,
                alignment: .center
            )
            .middleColumnSelectionStyle(
                isSelectedTheme,
                leadingExtension:
                    26,
                trailingExtension:
                    4
            )
            .contentShape(
                Rectangle()
            )
            .onTapGesture {
                workCreationRequest =
                    nil

                selectedWorkItemID =
                    nil

                selection =
                    theme.id
            }
        }
        .sheet(
            item: $createKind
        ) { kind in
            CreateWorkItemView(
                themeID: theme.id,
                parentWorkItemID: nil,
                initialKind: kind,
                isPresented:
                    Binding(
                        get: {
                            createKind != nil
                        },
                        set: { newValue in
                            if !newValue {
                                createKind = nil
                            }
                        }
                    )
            )
        }
        .sheet(
            isPresented:
                $showingCreateSubtheme
        ) {
            CreateThemeView(
                isPresented:
                    $showingCreateSubtheme,
                initialParentID:
                    theme.id
            )
        }
    }
}

private struct WorkItemNodeView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let item: WorkItem

    @Binding
    var selectedWorkItemID:
        UUID?

    @Binding
    var workCreationRequest:
        WorkCreationRequest?

    init(
        item: WorkItem,
        selectedWorkItemID:
            Binding<UUID?> =
                .constant(nil),
        workCreationRequest:
            Binding<WorkCreationRequest?> =
                .constant(nil),
        initiallyExpanded:
            Bool = true
    ) {
        self.item =
            item

        self._selectedWorkItemID =
            selectedWorkItemID

        self._workCreationRequest =
            workCreationRequest

        self._isExpanded =
            State(
                initialValue:
                    initiallyExpanded
            )
    }

    @State
    private var isExpanded:
        Bool

    @State
    private var createKind:
        WorkItemKind?

    var body: some View {
        let children =
            store.childWorkItems(
                of: item.id
            )

        if children.isEmpty {
            selectableLabel
                .sheet(
                    item: $createKind
                ) { kind in
                    createSheet(kind)
                }
                .contextMenu {
                    contextMenuContent
                }
        } else {
            DisclosureGroup(
                isExpanded: $isExpanded
            ) {
                ForEach(children) { child in
                    WorkItemNodeView(
                        item: child,
                        selectedWorkItemID:
                            $selectedWorkItemID,
                        workCreationRequest:
                            $workCreationRequest
                    )
                }
            } label: {
                selectableLabel
            }
            .sheet(
                item: $createKind
            ) { kind in
                createSheet(kind)
            }
            .contextMenu {
                contextMenuContent
            }
        }
    }

    private var isSelectedWorkItem:
        Bool
    {
        selectedWorkItemID
            == item.id
    }


    private var selectableLabel:
        some View
    {
        label
            .middleColumnSelectionStyle(
                isSelectedWorkItem,
                leadingExtension:
                    26,
                trailingExtension:
                    4
            )
            .contentShape(
                Rectangle()
            )
            .onTapGesture {
                selectItem()
            }
    }

    private func selectItem() {
        workCreationRequest =
            nil

        selectedWorkItemID =
            item.id
    }


    private var label: some View {
        HStack(spacing: 8) {
            HStack(
                alignment: .top,
                spacing: 8
            ) {
                Image(
                    systemName: itemIcon
                )
                .foregroundStyle(
                    item.kind == .task
                    ? (
                        item.status
                        ?? .todo
                    )
                        .testudoStatusIconColor
                    : (
                        isSelectedWorkItem
                        ? Color.white
                        : Color.secondary
                    )
                )
                .padding(
                    .top,
                    2
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(displayTitle)
                        .lineLimit(1)

                    if
                        item.kind == .task,
                        let status =
                            item.status
                    {
                        Text(
                            status.displayName
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            isSelectedWorkItem
                            ? Color.white.opacity(0.85)
                            : Color.secondary
                        )

                        if let deadline =
                            item.deadlineAt
                        {
                            Text(
                                "Deadline: \(TestudoTime.displayDateTime(deadline, sourceTimeZoneID: item.deadlineTimeZoneID))"
                            )
                            .font(.caption2)
                            .foregroundStyle(
                                isSelectedWorkItem
                                ? Color.white.opacity(0.85)
                                : (
                                    deadline < Date()
                                    && status != .completed
                                    ? Color.red
                                    : Color.secondary
                                )
                            )
                        }
                    } else {
                        Text(
                            item.kind.displayName
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            isSelectedWorkItem
                            ? Color.white.opacity(0.85)
                            : Color.secondary
                        )
                    }
                }
            }

            Spacer()

            Menu {
                Button("New Task") {
                    createKind = .task
                }

                Button("New Note") {
                    createKind = .note
                }

                Button("New Activity") {
                    createKind = .activity
                }
            } label: {
                Image(
                    systemName:
                        "plus.circle"
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .frame(
            height: 46,
            alignment: .center
        )
    }


    @ViewBuilder
    private var contextMenuContent:
        some View
    {
        if item.kind == .task {
            Menu("Status") {
                ForEach(
                    TaskStatus.allCases
                ) { status in
                    Button(
                        status.displayName
                    ) {
                        store.setTaskStatus(
                            workItemID:
                                item.id,
                            status: status
                        )
                    }
                }
            }

            Divider()
        }

        Button("New Task") {
            createKind = .task
        }

        Button("New Note") {
            createKind = .note
        }

        Button("New Activity") {
            createKind = .activity
        }

    }

    private func createSheet(
        _ kind: WorkItemKind
    ) -> some View {
        CreateWorkItemView(
            themeID: item.themeID,
            parentWorkItemID:
                item.id,
            initialKind: kind,
            isPresented:
                Binding(
                    get: {
                        createKind != nil
                    },
                    set: { newValue in
                        if !newValue {
                            createKind = nil
                        }
                    }
                )
        )
    }

    private var displayTitle: String {
        if
            let title = item.title,
            !title.isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return item.kind.displayName
    }

    private var itemIcon: String {
        switch item.kind {
        case .task:
            if item.status == .completed {
                return "checkmark.circle"
            }

            if item.status == .inProgress {
                return "clock"
            }

            return "circle"

        case .note:
            return "note.text"

        case .activity:
            return "waveform.path.ecg"
        }
    }
}

private struct AllTasksView: View {
    @EnvironmentObject
    private var store: TestudoStore

    var body: some View {
        let rootThemes =
            store.childThemes(of: nil)

        if store.data.workItems
            .filter({ $0.kind == .task })
            .isEmpty
        {
            ContentUnavailableView {
                Label(
                    "No Tasks Yet",
                    systemImage:
                        "list.bullet.indent"
                )
            } description: {
                Text(
                    "Tasks created inside your themes will appear here."
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List {
                ForEach(rootThemes) { theme in
                    AllTasksThemeNodeView(
                        theme: theme
                    )
                }
            }
        }
    }
}

private struct AllTasksThemeNodeView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let theme: Theme

    @State
    private var isExpanded = true

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded
        ) {
            ForEach(
                store.rootWorkItems(
                    for: theme.id
                )
            ) { item in
                TaskHierarchyRootView(
                    item: item
                )
            }

            ForEach(
                store.childThemes(
                    of: theme.id
                )
            ) { childTheme in
                AllTasksThemeNodeView(
                    theme: childTheme
                )
            }
        } label: {
            Label(
                theme.name,
                systemImage: "folder"
            )
            .fontWeight(.semibold)
        }
    }
}

private struct TaskHierarchyRootView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let item: WorkItem

    var body: some View {
        if item.kind == .task {
            WorkItemNodeView(
                item: item
            )
        } else {
            ForEach(
                store.childWorkItems(
                    of: item.id
                )
            ) { child in
                TaskHierarchyRootView(
                    item: child
                )
            }
        }
    }
}

private struct StatusTaskListView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let status: TaskStatus

    var body: some View {
        let tasks =
            store.tasks(with: status)

        if tasks.isEmpty {
            ContentUnavailableView {
                Label(
                    "No \(status.displayName) Tasks",
                    systemImage: icon
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List(tasks) { task in
                WorkSummaryRow(
                    item: task
                )
                .contextMenu {
                    Menu("Status") {
                        ForEach(
                            TaskStatus.allCases
                        ) { newStatus in
                            Button(
                                newStatus.displayName
                            ) {
                                store.setTaskStatus(
                                    workItemID:
                                        task.id,
                                    status:
                                        newStatus
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var icon: String {
        switch status {
        case .todo:
            return "circle"
        case .inProgress:
            return "clock"
        case .completed:
            return "checkmark.circle"
                case .closed:
            return "archivebox"

}
    }
}

private struct TodayView: View {
    @EnvironmentObject
    private var store: TestudoStore

    var body: some View {
        let items =
            store.todayWorkItems()

        if items.isEmpty {
            ContentUnavailableView {
                Label(
                    "No Activity Today",
                    systemImage:
                        "calendar"
                )
            } description: {
                Text(
                    "Work created, started, completed or logged today will appear here."
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List(items) { item in
                WorkSummaryRow(
                    item: item
                )
            }
        }
    }
}

private struct WorkSummaryRow: View {
    @EnvironmentObject
    private var store: TestudoStore

    let item: WorkItem

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            Image(
                systemName: icon
            )
            .frame(width: 20)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(displayTitle)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if
                        let theme =
                            store.theme(
                                id: item.themeID
                            )
                    {
                        Text(theme.name)
                    }

                    Text(
                        item.kind.displayName
                    )

                    if
                        let status =
                            item.status
                    {
                        Text(
                            status.displayName
                        )
                    }

                    if let deadline =
                        item.deadlineAt
                    {
                        Text(
                            "Due \(deadline.formatted(date: .abbreviated, time: .omitted))"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if
                    item.title != nil,
                    !item.body.isEmpty
                {
                    Text(item.body)
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(
                item.updatedAt,
                format:
                    .dateTime
                    .hour()
                    .minute()
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    private var displayTitle: String {
        if
            let title = item.title,
            !title.isEmpty
        {
            return title
        }

        return item.body
    }

    private var icon: String {
        switch item.kind {
        case .task:
            switch item.status {
            case .todo:
                return "circle"
            case .inProgress:
                return "clock"
            case .completed:
                return "checkmark.circle"
            case .closed:
                return "archivebox"

            case nil:
                return "circle"
            }

        case .note:
            return "note.text"

        case .activity:
            return "waveform.path.ecg"
        }
    }
}

private struct TimelineView: View {
    @EnvironmentObject
    private var store: TestudoStore

    var body: some View {
        let events =
            store.data.historyEvents
                .sorted {
                    $0.timestamp
                    > $1.timestamp
                }

        if events.isEmpty {
            ContentUnavailableView {
                Label(
                    "No History Yet",
                    systemImage:
                        "list.bullet.rectangle"
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List(events) { event in
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Image(
                        systemName:
                            historyIcon(
                                event.kind
                            )
                    )
                    .frame(width: 20)

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(
                            workTitle(
                                event.workItemID
                            )
                        )
                        .fontWeight(.medium)

                        Text(
                            event.text
                            ?? historyName(
                                event.kind
                            )
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Text(
                        event.timestamp,
                        format:
                            .dateTime
                            .day()
                            .month()
                            .hour()
                            .minute()
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .tertiary
                    )
                }
                .padding(
                    .vertical,
                    3
                )
            }
        }
    }

    private func workTitle(
        _ id: UUID
    ) -> String {
        guard
            let item =
                store.workItem(id: id)
        else {
            return "Work item"
        }

        if
            let title = item.title,
            !title.isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return item.kind.displayName
    }

    private func historyName(
        _ kind: HistoryEventKind
    ) -> String {
        switch kind {
        case .created:
            return "Created"
        case .edited:
            return "Edited"
        case .statusChanged:
            return "Status changed"
        case .scheduled:
            return "Scheduled"
        case .started:
            return "Started"
        case .completed:
            return "Completed"
        case .activityLogged:
            return "Activity logged"
        case .relationshipAdded:
            return "Relationship added"
        case .relationshipRemoved:
            return "Relationship removed"
        case .moved:
            return "Moved"
        }
    }

    private func historyIcon(
        _ kind: HistoryEventKind
    ) -> String {
        switch kind {
        case .created:
            return "plus.circle"
        case .edited:
            return "pencil"
        case .statusChanged:
            return "arrow.triangle.2.circlepath"
        case .scheduled:
            return "calendar"
        case .started:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .activityLogged:
            return "waveform.path.ecg"
        case .relationshipAdded:
            return "link.badge.plus"
        case .relationshipRemoved:
            return "link.badge.minus"
        case .moved:
            return "arrow.right"
        }
    }
}

private struct CreateWorkItemView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let themeID: UUID?
    let parentWorkItemID: UUID?

    @Binding
    var isPresented: Bool

    @State
    private var kind: WorkItemKind

    @State
    private var title = ""

    @State
    private var bodyText = ""

    @State
    private var hasDeadline = false

    @State
    private var deadlineAt =
        Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Date()
        ) ?? Date()

    @State
    private var deadlineTimeZoneID =
        TestudoTime.deviceTimeZoneID


    init(
        themeID: UUID?,
        parentWorkItemID: UUID?,
        initialKind: WorkItemKind,
        isPresented: Binding<Bool>
    ) {
        self.themeID = themeID
        self.parentWorkItemID =
            parentWorkItemID

        self._kind =
            State(
                initialValue:
                    initialKind
            )

        self._isPresented =
            isPresented
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 18
        ) {
            Text("New Work Entry")
                .font(.title2)
                .fontWeight(.semibold)

            Picker(
                "Type",
                selection: $kind
            ) {
                ForEach(
                    WorkItemKind.allCases
                ) { kind in
                    Text(kind.displayName)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)

            TextField(
                "Title (optional)",
                text: $title
            )

            Text("Text")
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            TextEditor(
                text: $bodyText
            )
            .font(.body)
            .frame(
                minHeight: 170
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 6
                )
                .stroke(
                    Color.secondary
                        .opacity(0.25)
                )
            }

            if kind == .task {
                Divider()

                Toggle(
                    "Deadline",
                    isOn: $hasDeadline
                )

                if hasDeadline {
                    TimeZoneAwareDateEditor(
                        label: "Due",
                        date:
                            $deadlineAt,
                        timeZoneID:
                            $deadlineTimeZoneID
                    )
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }

                Button("Create") {
                    store.createWorkItem(
                        themeID: themeID,
                        parentWorkItemID:
                            parentWorkItemID,
                        kind: kind,
                        title: title,
                        body: bodyText,
                        deadlineAt:
                            kind == .task
                            && hasDeadline
                            ? deadlineAt
                            : nil,
                        deadlineTimeZoneID:
                            kind == .task
                            && hasDeadline
                            ? deadlineTimeZoneID
                            : nil
                    )

                    isPresented = false
                }
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(!hasContent)
            }
        }
        .padding(24)
        .frame(
            width: 520
        )
    }

    private var hasContent: Bool {
        !title
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        || !bodyText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }
}

private struct EntityListView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let kind: EntityKind

    @Binding
    var selection: UUID?

    var body: some View {
        let entities =
            store.entities(of: kind)

        if entities.isEmpty {
            ContentUnavailableView {
                Label(
                    emptyTitle,
                    systemImage: icon
                )
            } description: {
                Text(emptyDescription)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List(
                entities,
                selection:
                    $selection
            ) { entity in
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(entity.name)

                    let containers =
                        store.containers(
                            for: entity.id
                        )

                    if !containers.isEmpty {
                        Text(
                            containers
                                .map(\.name)
                                .joined(
                                    separator: " · "
                                )
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                    } else {
                        Text("Independent")
                            .font(.caption)
                            .foregroundStyle(
                                .tertiary
                            )
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch kind {
        case .organization:
            return "No Organizations Yet"
        case .group:
            return "No Groups Yet"
        case .person:
            return "No People Yet"
        }
    }

    private var emptyDescription: String {
        switch kind {
        case .organization:
            return
                "Create an organization or sub-organization."

        case .group:
            return
                "Create a group inside an organization or independently."

        case .person:
            return
                "Create a person and optionally assign an initial affiliation."
        }
    }

    private var icon: String {
        switch kind {
        case .organization:
            return "building.2"
        case .group:
            return "person.3"
        case .person:
            return "person.2"
        }
    }
}

private struct CreateThemeView: View {
    @EnvironmentObject
    private var store: TestudoStore

    @Binding
    var isPresented: Bool

    @State
    private var name = ""

    @State
    private var parentID: UUID?

    init(
        isPresented:
            Binding<Bool>,
        initialParentID:
            UUID? = nil
    ) {
        self._isPresented =
            isPresented

        self._parentID =
            State(
                initialValue:
                    initialParentID
            )
    }


    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Text("New Theme")
                .font(.title2)
                .fontWeight(.semibold)

            TextField(
                "Theme name",
                text: $name
            )

            Picker(
                "Parent theme",
                selection: $parentID
            ) {
                Text("None")
                    .tag(
                        Optional<UUID>.none
                    )

                ForEach(
                    store.data.themes
                        .sorted {
                            $0.name
                                .localizedCaseInsensitiveCompare(
                                    $1.name
                                )
                                == .orderedAscending
                        }
                ) { theme in
                    Text(theme.name)
                        .tag(
                            Optional(
                                theme.id
                            )
                        )
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }

                Button("Create") {
                    store.createTheme(
                        name: name,
                        parentThemeID:
                            parentID
                    )

                    isPresented = false
                }
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    name
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

private struct CreateEntityView: View {
    @EnvironmentObject
    private var store: TestudoStore

    let kind: EntityKind

    @Binding
    var isPresented: Bool

    @State
    private var name = ""

    @State
    private var containerID: UUID?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            TextField(
                namePrompt,
                text: $name
            )

            Picker(
                containerLabel,
                selection: $containerID
            ) {
                Text("None")
                    .tag(
                        Optional<UUID>.none
                    )

                ForEach(
                    store.possibleContainers(
                        for: kind
                    )
                ) { entity in
                    Text(
                        containerDescription(
                            entity
                        )
                    )
                    .tag(
                        Optional(entity.id)
                    )
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }

                Button("Create") {
                    store.createEntity(
                        kind: kind,
                        name: name,
                        initialContainerID:
                            containerID
                    )

                    isPresented = false
                }
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    name
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var title: String {
        switch kind {
        case .organization:
            return "New Organization"
        case .group:
            return "New Group"
        case .person:
            return "New Person"
        }
    }

    private var namePrompt: String {
        switch kind {
        case .organization:
            return "Organization name"
        case .group:
            return "Group name"
        case .person:
            return "Person name"
        }
    }

    private var containerLabel: String {
        switch kind {
        case .organization:
            return "Parent organization"
        case .group:
            return "Organization or group"
        case .person:
            return "Initial affiliation"
        }
    }

    private func containerDescription(
        _ entity: Entity
    ) -> String {
        switch entity.kind {
        case .organization:
            return
                "\(entity.name) — Organization"

        case .group:
            return
                "\(entity.name) — Group"

        case .person:
            return entity.name
        }
    }
}

struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
            }
            .frame(height: 48)
            .background(
                TestudoStyle.headerBackground
            )

            ZStack {
                TestudoStyle.contentBackground

                ContentUnavailableView {
                    Label(
                        "Nothing Selected",
                        systemImage: "doc.text"
                    )
                } description: {
                    Text(
                        "Select a task, note, activity entry or entity."
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .ignoresSafeArea(
            .container,
            edges: .top
        )
    }
}

struct SettingsView: View {
    @EnvironmentObject
    private var store: TestudoStore

    @State
    private var showingProfileEditor =
        false

    @State
    private var showingResetConfirmation =
        false


    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                header

                settingsSection(
                    "My Profile"
                ) {
                    profileContent
                }

                settingsSection(
                    "Portable Profile"
                ) {
                    VStack(
                        alignment:
                            .leading,
                        spacing:
                            10
                    ) {

                        Text(
                            "Save your personal Testudo profile as a portable .testudouser file."
                        )
                        .font(
                            .callout
                        )


                        Text(
                            "The file contains your profile information only. It does not contain your application password, Work Environments, Environment passwords or remembered sign-ins."
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )


                        TestudoUserProfileExportButton()
                    }
                }


                settingsSection(
                    "My Profile in Current Environment"
                ) {
                    CurrentEnvironmentProfileImportSummaryView()
                }

                settingsSection(
                    "Application"
                ) {
                    settingsRow(
                        label:
                            "Environment registry",
                        value:
                            "Local to this installation"
                    )

                    settingsRow(
                        label:
                            "Known Work Environments",
                        value:
                            "\(store.workEnvironments.count)"
                    )
                }

                settingsSection(
                    "Work Environments"
                ) {
                    WorkEnvironmentSettingsManagementView()
                }

                settingsSection(
                    "Application Data"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        Text(
                            "Application database"
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            store
                                .applicationFileURL
                                .path
                        )
                        .font(
                            .system(
                                size: 11,
                                design:
                                    .monospaced
                            )
                        )
                        .textSelection(
                            .enabled
                        )
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )
                    }
                }

                settingsSection(
                    "Sign Out from Testudo"
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        Text(
                            "Signing out removes this local Testudo profile, application password, Work Environment registry, bookmarks and remembered Environment identity mappings from this Mac."
                        )
                        .font(.callout)

                        Text(
                            "Your .testudoenv packages and their contents are not deleted. If you only want to lock Testudo and return later to the same state, use Log Out instead."
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )

                        Button(
                            "Sign Out from Testudo…",
                            role:
                                .destructive
                        ) {
                            showingResetConfirmation =
                                true
                        }
                        .padding(
                            .top,
                            2
                        )
                    }
                }
            }
            .padding(
                28
            )
            .frame(
                maxWidth:
                    720,
                alignment:
                    .leading
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .center
            )
        }
        .frame(
            minWidth:
                640,
            idealWidth:
                700,
            minHeight:
                560,
            idealHeight:
                620
        )
        .sheet(
            isPresented:
                $showingProfileEditor
        ) {
            if
                let profile =
                    store.localUserProfile
            {
                LocalUserProfileEditorView(
                    profile:
                        profile
                )
            }
        }
        .sheet(
            isPresented:
                $showingResetConfirmation
        ) {
            ApplicationSignOutConfirmationView {
                store
                    .signOutApplicationAndRemoveLocalData()

                showingResetConfirmation =
                    false
            }
        }
    }


    private var header:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(
                "Settings"
            )
            .font(.title2)
            .fontWeight(
                .semibold
            )

            Text(
                "Settings for this application installation."
            )
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
        }
    }


    @ViewBuilder
    private var profileContent:
        some View
    {
        if
            let profile =
                store.localUserProfile
        {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                settingsRow(
                    label:
                        "Name",
                    value:
                        profile.displayName
                )

                if
                    !profile
                        .professionalEmail
                        .isEmpty
                {
                    settingsRow(
                        label:
                            "Email",
                        value:
                            profile
                                .professionalEmail
                    )
                }

                Button(
                    "Edit My Profile…"
                ) {
                    showingProfileEditor =
                        true
                }
                .padding(
                    .top,
                    2
                )
            }

        } else {
            Text(
                "No local application profile exists."
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    private func settingsRow(
        label:
            String,
        value:
            String
    ) -> some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                18
        ) {
            Text(
                label
            )
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
            .frame(
                width:
                    180,
                alignment:
                    .leading
            )

            Text(
                value
            )
            .font(.callout)
            .textSelection(
                .enabled
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
        }
    }


    private func settingsSection<
        Content:
            View
    >(
        _ title:
            String,
        @ViewBuilder
        content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                title
            )
            .font(.headline)

            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                content()
            }
            .padding(
                14
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
            .background {
                RoundedRectangle(
                    cornerRadius:
                        10,
                    style:
                        .continuous
                )
                .fill(
                    Color.primary
                        .opacity(
                            0.035
                        )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius:
                        10,
                    style:
                        .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(
                            0.08
                        ),
                    lineWidth:
                        1
                )
            }
        }
    }
}
