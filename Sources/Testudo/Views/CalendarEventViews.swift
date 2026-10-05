import SwiftUI


struct CalendarEventCreationRequest:
    Identifiable,
    Equatable
{
    let id =
        UUID()

    let date:
        Date
}


// ============================================================
// MARK: - Shared UI
// ============================================================

private struct CalendarEditActions:
    View
{
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(
                "Cancel",
                action: cancel
            )

            Button(
                "Save",
                action: save
            )
            .keyboardShortcut(
                .defaultAction
            )
        }
        .buttonStyle(.borderless)
    }
}


private struct CalendarPropertyRow:
    View
{
    @Environment(
        \.testudoDetailNavigation
    )
    private var detailNavigation

    let label: String
    let value: String

    var navigationDestination:
        TestudoDetailDestination? =
            nil

    var editable:
        Bool = true

    let edit: () -> Void

    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing: 14
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 120,
                    alignment: .leading
                )

            if
                let navigationDestination,
                !value.isEmpty
            {
                Button {
                    detailNavigation(
                        navigationDestination
                    )

                } label: {
                    Text(
                        value
                    )
                    .foregroundStyle(
                        .primary
                    )
                }
                .buttonStyle(
                    .plain
                )
                .help(
                    "Open \(value)"
                )

            } else {
                Text(
                    value.isEmpty
                    ? "None"
                    : value
                )
                .foregroundStyle(
                    value.isEmpty
                    ? .tertiary
                    : .primary
                )
                .textSelection(
                    .enabled
                )
            }

            Spacer()

            if editable {
                Button(
                    action: edit
                ) {
                    Image(
                        systemName: "pencil"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                    .frame(
                        width: 20,
                        height: 20
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
    }
}


private struct CalendarInspectorSection<
    Content: View
>: View
{
    let title: String

    @ViewBuilder
    let content: () -> Content

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(.headline)

            content()
        }
    }
}


// ============================================================
// MARK: - Agenda Row
// ============================================================

struct CalendarEventAgendaRow:
    View
{
    let event:
        CalendarEvent

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 9
        ) {
            Image(
                systemName:
                    event.isAllDay
                    ? "calendar"
                    : "calendar.badge.clock"
            )
            .frame(
                width: 18
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(event.title)
                    .lineLimit(1)

                Text(timeDescription)
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)

                if
                    let location =
                        event.location,
                    !location.isEmpty
                {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(
            Rectangle()
        )
    }


    private var timeDescription:
        String
    {
        if event.isAllDay {
            return "All day"
        }

        let start =
            event.startAt.formatted(
                date: .omitted,
                time: .shortened
            )

        let end =
            event.endAt.formatted(
                date: .omitted,
                time: .shortened
            )

        return "\(start) – \(end)"
    }
}


// ============================================================
// MARK: - Creation
// ============================================================

struct CalendarEventCreationView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    let request:
        CalendarEventCreationRequest

    @Binding
    var creationRequest:
        CalendarEventCreationRequest?

    @Binding
    var selectedCalendarEventID:
        UUID?

    @State
    private var title =
        ""

    @State
    private var notes =
        ""

    @State
    private var location =
        ""

    @State
    private var startAt:
        Date

    @State
    private var endAt:
        Date

    @State
    private var isAllDay =
        false

    @State
    private var startTimeZoneID =
        TestudoTime.deviceTimeZoneID

    @State
    private var endTimeZoneID =
        TestudoTime.deviceTimeZoneID

    @State
    private var calendarID:
        UUID?

    @State
    private var workIDs:
        Set<UUID> = []

    @State
    private var themeIDs:
        Set<UUID> = []

    @State
    private var errorMessage:
        String?


    init(
        request:
            CalendarEventCreationRequest,
        creationRequest:
            Binding<CalendarEventCreationRequest?>,
        selectedCalendarEventID:
            Binding<UUID?>
    ) {
        self.request =
            request

        self._creationRequest =
            creationRequest

        self._selectedCalendarEventID =
            selectedCalendarEventID

        let calendar =
            Calendar.autoupdatingCurrent

        let day =
            calendar.startOfDay(
                for: request.date
            )

        let start =
            calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: day
            ) ?? day

        let end =
            calendar.date(
                byAdding: .hour,
                value: 1,
                to: start
            ) ?? start

        self._startAt =
            State(
                initialValue: start
            )

        self._endAt =
            State(
                initialValue: end
            )
    }


    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(
                            "New Calendar Event"
                        )
                        .font(.title2)
                        .fontWeight(
                            .semibold
                        )

                        Text(
                            request.date.formatted(
                                date: .long,
                                time: .omitted
                            )
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()
                }

                CalendarInspectorSection(
                    title: "Event"
                ) {
                    VStack(
                        spacing: 12
                    ) {
                        TextField(
                            "Title",
                            text: $title
                        )

                        Picker(
                            "Calendar",
                            selection:
                                $calendarID
                        ) {
                            Text(
                                "Local / Unassigned"
                            )
                            .tag(
                                Optional<UUID>.none
                            )

                            ForEach(
                                store.data.calendars
                                    .filter {
                                        !$0.isReadOnly
                                    }
                            ) { calendar in
                                Text(calendar.name)
                                    .tag(
                                        Optional(
                                            calendar.id
                                        )
                                    )
                            }
                        }

                        Toggle(
                            "All day",
                            isOn: $isAllDay
                        )

                        dateEditor(
                            label: "Start",
                            date: $startAt,
                            timeZoneID:
                                $startTimeZoneID
                        )

                        dateEditor(
                            label: "End",
                            date: $endAt,
                            timeZoneID:
                                $endTimeZoneID
                        )

                        TextField(
                            "Location",
                            text: $location
                        )
                    }
                }

                CalendarInspectorSection(
                    title: "Notes"
                ) {
                    TextEditor(
                        text: $notes
                    )
                    .frame(
                        minHeight: 100
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 6
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.15)
                        )
                    }
                }

                CalendarInspectorSection(
                    title: "Related Tasks"
                ) {
                    HierarchicalSelectionSummaryRow(
                        label:
                            "Tasks",
                        selectedTitles:
                            taskCandidates
                                .filter {
                                    workIDs.contains(
                                        $0.id
                                    )
                                }
                                .map(workName),
                        selectorTitle:
                            "Related Tasks",
                        selectorMessage:
                            "Tasks are displayed as Task → Sub-task → deeper levels.",
                        nodes:
                            HierarchySelectionData
                                .taskNodes(
                                    store:
                                        store
                                ),
                        initialSelection:
                            workIDs,
                        onSave: {
                            selection in

                            workIDs =
                                selection

                            return nil
                        }
                    )
                }

                CalendarInspectorSection(
                    title: "Related Themes"
                ) {
                    HierarchicalSelectionSummaryRow(
                        label:
                            "Themes",
                        selectedTitles:
                            themeCandidates
                                .filter {
                                    themeIDs.contains(
                                        $0.id
                                    )
                                }
                                .map(\.name),
                        selectorTitle:
                            "Related Themes",
                        selectorMessage:
                            "Themes are displayed as Theme → Sub-theme → deeper levels.",
                        nodes:
                            HierarchySelectionData
                                .themeNodes(
                                    store:
                                        store
                                ),
                        initialSelection:
                            themeIDs,
                        onSave: {
                            selection in

                            themeIDs =
                                selection

                            return nil
                        }
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(
                            .red
                        )
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        creationRequest =
                            nil
                    }

                    Button("Create") {
                        create()
                    }
                    .keyboardShortcut(
                        .defaultAction
                    )
                    .disabled(
                        title
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                    )
                }
            }
            .padding(
                .horizontal,
                28
            )
            .padding(
                .top,
                8
            )
            .padding(
                .bottom,
                28
            )
            .frame(
                maxWidth: 760,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
        }
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    @ViewBuilder
    private func dateEditor(
        label: String,
        date: Binding<Date>,
        timeZoneID: Binding<String>
    ) -> some View {
        TimeZoneAwareDateEditor(
            label:
                label,
            date:
                date,
            timeZoneID:
                timeZoneID,
            includesTime:
                !isAllDay
        )
    }


    @ViewBuilder
    private func relationChecklist<
        T: Identifiable
    >(
        items: [T],
        selectedIDs:
            Binding<Set<UUID>>,
        label:
            @escaping (T) -> String
    ) -> some View
    where T.ID == UUID
    {
        if items.isEmpty {
            Text("None available")
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
        } else {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(items) { item in
                    Toggle(
                        label(item),
                        isOn:
                            membershipBinding(
                                id: item.id,
                                set:
                                    selectedIDs
                            )
                    )
                    .toggleStyle(
                        .checkbox
                    )
                }
            }
        }
    }


    private func membershipBinding(
        id: UUID,
        set:
            Binding<Set<UUID>>
    ) -> Binding<Bool> {
        Binding(
            get: {
                set.wrappedValue
                    .contains(id)
            },
            set: {
                enabled in

                if enabled {
                    set.wrappedValue
                        .insert(id)
                } else {
                    set.wrappedValue
                        .remove(id)
                }
            }
        )
    }


    private var taskCandidates:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                $0.kind == .task
            }
            .sorted {
                workName($0)
                    .localizedCaseInsensitiveCompare(
                        workName($1)
                    )
                    == .orderedAscending
            }
    }


    private var themeCandidates:
        [Theme]
    {
        store.data.themes
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private func workName(
        _ item: WorkItem
    ) -> String {
        if
            let title =
                item.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !title.isEmpty
        {
            return title
        }

        let body =
            item.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !body.isEmpty {
            return String(
                body.prefix(70)
            )
        }

        return "Untitled Task"
    }


    private func create() {
        errorMessage =
            nil

        guard
            endAt >= startAt
        else {
            errorMessage =
                "End time cannot be earlier than start time."
            return
        }

        guard
            let id =
                store.createCalendarEvent(
                    calendarID:
                        calendarID,
                    title:
                        title,
                    notes:
                        notes,
                    location:
                        location
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? nil
                        : location,
                    startAt:
                        startAt,
                    endAt:
                        endAt,
                    isAllDay:
                        isAllDay,
                    startTimeZoneID:
                        isAllDay
                        ? nil
                        : startTimeZoneID,
                    endTimeZoneID:
                        isAllDay
                        ? nil
                        : endTimeZoneID
                )
        else {
            errorMessage =
                "The Calendar Event could not be created."
            return
        }

        if
            let error =
                store
                    .setCalendarEventWorkLinks(
                        calendarEventID:
                            id,
                        workItemIDs:
                            workIDs
                    )
        {
            errorMessage =
                error
            return
        }

        if
            let error =
                store
                    .setCalendarEventThemeLinks(
                        calendarEventID:
                            id,
                        themeIDs:
                            themeIDs
                    )
        {
            errorMessage =
                error
            return
        }

        selectedCalendarEventID =
            id

        creationRequest =
            nil
    }
}


// ============================================================
// MARK: - Detail Inspector
// ============================================================

struct CalendarEventDetailView:
    View
{
    @EnvironmentObject
    private var store:
        TestudoStore

    let eventID:
        UUID

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        eventID: UUID,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.eventID =
            eventID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft =
        ""

    @State
    private var dateDraft =
        Date()

    @State
    private var timeZoneDraft =
        TestudoTime.deviceTimeZoneID

    @State
    private var boolDraft =
        false

    @State
    private var calendarIDDraft:
        UUID?

    @State
    private var statusDraft:
        CalendarEventStatus =
        .confirmed

    @State
    private var workIDsDraft:
        Set<UUID> = []

    @State
    private var themeIDsDraft:
        Set<UUID> = []

    @State
    private var errorMessage:
        String?


    private enum EditableField:
        Hashable
    {
        case title
        case calendar
        case status
        case allDay
        case start
        case end
        case location
        case notes
        case work
        case themes
    }


    var body: some View {
        ZStack {
            TestudoStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let event =
                    store.calendarEvent(
                        id: eventID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 26
                    ) {
                        header(event)

                        if
                            store
                                .isReadOnlyCalendarEvent(
                                    event
                                )
                        {
                            Label(
                                "Read-only external calendar. Event details come from the connected calendar; only Testudo relationships can be changed.",
                                systemImage:
                                    "lock"
                            )
                            .font(.callout)
                            .foregroundStyle(
                                .secondary
                            )
                            .padding(
                                .vertical,
                                6
                            )
                        }

                        CalendarInspectorSection(
                            title: "Schedule"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                calendarRow(event)
                                statusRow(event)
                                allDayRow(event)
                                dateRow(
                                    event,
                                    label: "Start",
                                    value:
                                        event.startAt,
                                    timeZoneID:
                                        event.startTimeZoneID,
                                    field: .start
                                )
                                dateRow(
                                    event,
                                    label: "End",
                                    value:
                                        event.endAt,
                                    timeZoneID:
                                        event.endTimeZoneID,
                                    field: .end
                                )
                            }
                        }

                        CalendarInspectorSection(
                            title: "Details"
                        ) {
                            VStack(
                                spacing: 10
                            ) {
                                textRow(
                                    event,
                                    label: "Location",
                                    value:
                                        event.location,
                                    field:
                                        .location
                                )

                                textRow(
                                    event,
                                    label: "Notes",
                                    value:
                                        event.notes,
                                    field:
                                        .notes,
                                    multiline:
                                        true
                                )
                            }
                        }

                        CalendarInspectorSection(
                            title: "Related Work"
                        ) {
                            workLinksRow(event)
                        }

                        CalendarInspectorSection(
                            title: "Related Themes"
                        ) {
                            themeLinksRow(event)
                        }

                        CalendarInspectorSection(
                            title: "Sync"
                        ) {
                            VStack(
                                spacing: 9
                            ) {
                                readonlyRow(
                                    label: "State",
                                    value:
                                        event.syncState
                                            .rawValue
                                )

                                readonlyRow(
                                    label: "External ID",
                                    value:
                                        event.externalID
                                        ?? "None"
                                )

                                readonlyRow(
                                    label: "iCal UID",
                                    value:
                                        event.iCalUID
                                        ?? "None"
                                )
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(
                                    .red
                                )
                        }

                        CalendarInspectorSection(
                            title: "History"
                        ) {
                            VStack(
                                spacing: 9
                            ) {
                                readonlyRow(
                                    label: "Created",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                event.createdAt
                                            ),
                                    dateDestination:
                                        event.createdAt
                                )

                                readonlyRow(
                                    label: "Updated",
                                    value:
                                        TestudoTime
                                            .dateTime(
                                                event.updatedAt
                                            ),
                                    dateDestination:
                                        event.updatedAt
                                )
                            }
                        }

                        // DETAIL DELETE FOOTER
                        HStack {
                            Spacer()

                            detailDeleteFooter

                            Spacer()
                        }
                        .padding(.top, 8)
}
                    .padding(
                        .horizontal,
                        28
                    )
                    .padding(
                        .top,
                        8
                    )
                    .padding(
                        .bottom,
                        28
                    )
                    .frame(
                        maxWidth: 760,
                        alignment: .leading
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                }
            } else {
                ContentUnavailableView(
                    "Calendar Event Not Found",
                    systemImage:
                        "calendar.badge.exclamationmark"
                )
            }
        }
    }


    @ViewBuilder
    private func header(
        _ event: CalendarEvent
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    event.isAllDay
                    ? "calendar"
                    : "calendar.badge.clock"
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                if editingField == .title {
                    TextField(
                        "Title",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    CalendarEditActions(
                        cancel:
                            cancelEdit,
                        save: {
                            saveText(
                                event,
                                field: .title
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(
                                .semibold
                            )

                        if
                            !store
                                .isReadOnlyCalendarEvent(
                                    event
                                )
                        {
                            Button {
                                beginText(
                                    .title,
                                    value:
                                        event.title
                                )
                            } label: {
                                Image(
                                    systemName:
                                        "pencil"
                                )
                                .font(
                                    .system(
                                        size: 10
                                    )
                                )
                                .foregroundStyle(
                                    .tertiary
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Calendar Event")
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
    }


    @ViewBuilder
    private func calendarRow(
        _ event: CalendarEvent
    ) -> some View {
        if editingField == .calendar {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Picker(
                    "Calendar",
                    selection:
                        $calendarIDDraft
                ) {
                    Text(
                        "Local / Unassigned"
                    )
                    .tag(
                        Optional<UUID>.none
                    )

                    ForEach(
                        store.data.calendars
                    ) { calendar in
                        Text(calendar.name)
                            .tag(
                                Optional(
                                    calendar.id
                                )
                            )
                    }
                }

                CalendarEditActions(
                    cancel:
                        cancelEdit,
                    save: {
                        var updated =
                            event

                        updated.calendarID =
                            calendarIDDraft

                        finish(
                            store
                                .updateCalendarEvent(
                                    updated
                                )
                        )
                    }
                )
            }
        } else {
            CalendarPropertyRow(
                label: "Calendar",
                value:
                    store
                        .dReportCalendar(
                            id:
                                event.calendarID
                        )?
                        .name
                    ?? "Local / Unassigned",
                editable:
                    !store
                        .isReadOnlyCalendarEvent(
                            event
                        ),
                edit: {
                    calendarIDDraft =
                        event.calendarID

                    editingField =
                        .calendar
                }
            )
        }
    }


    @ViewBuilder
    private func statusRow(
        _ event: CalendarEvent
    ) -> some View {
        if editingField == .status {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Picker(
                    "Status",
                    selection:
                        $statusDraft
                ) {
                    ForEach(
                        CalendarEventStatus
                            .allCases
                    ) { status in
                        Text(
                            status.displayName
                        )
                        .tag(status)
                    }
                }

                CalendarEditActions(
                    cancel:
                        cancelEdit,
                    save: {
                        var updated =
                            event

                        updated.status =
                            statusDraft

                        finish(
                            store
                                .updateCalendarEvent(
                                    updated
                                )
                        )
                    }
                )
            }
        } else {
            CalendarPropertyRow(
                label: "Status",
                value:
                    event.status
                        .displayName,
                editable:
                    !store
                        .isReadOnlyCalendarEvent(
                            event
                        ),
                edit: {
                    statusDraft =
                        event.status

                    editingField =
                        .status
                }
            )
        }
    }


    @ViewBuilder
    private func allDayRow(
        _ event: CalendarEvent
    ) -> some View {
        if editingField == .allDay {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Toggle(
                    "All day",
                    isOn: $boolDraft
                )

                CalendarEditActions(
                    cancel:
                        cancelEdit,
                    save: {
                        var updated =
                            event

                        updated.isAllDay =
                            boolDraft

                        finish(
                            store
                                .updateCalendarEvent(
                                    updated
                                )
                        )
                    }
                )
            }
        } else {
            CalendarPropertyRow(
                label: "All day",
                value:
                    event.isAllDay
                    ? "Yes"
                    : "No",
                editable:
                    !store
                        .isReadOnlyCalendarEvent(
                            event
                        ),
                edit: {
                    boolDraft =
                        event.isAllDay

                    editingField =
                        .allDay
                }
            )
        }
    }


    @ViewBuilder
    private func dateRow(
        _ event: CalendarEvent,
        label: String,
        value: Date,
        timeZoneID: String?,
        field: EditableField
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                LargeDateTimeEditor(
                    date:
                        $dateDraft,
                    timeZoneID:
                        $timeZoneDraft,
                    includesTime:
                        !event.isAllDay,
                    showsTimeZone:
                        !event.isAllDay
                )

                CalendarEditActions(
                    cancel:
                        cancelEdit,
                    save: {
                        var updated =
                            event

                        if field == .start {
                            updated.startAt =
                                dateDraft

                            updated.startTimeZoneID =
                                event.isAllDay
                                ? nil
                                : timeZoneDraft
                        } else {
                            updated.endAt =
                                dateDraft

                            updated.endTimeZoneID =
                                event.isAllDay
                                ? nil
                                : timeZoneDraft
                        }

                        finish(
                            store
                                .updateCalendarEvent(
                                    updated
                                )
                        )
                    }
                )
            }
        } else {
            CalendarPropertyRow(
                label: label,
                value:
                    dateDescription(
                        value,
                        allDay:
                            event.isAllDay,
                        timeZoneID:
                            timeZoneID
                    ),
                navigationDestination:
                    .calendarDay(
                        value
                    ),
                editable:
                    !store
                        .isReadOnlyCalendarEvent(
                            event
                        ),
                edit: {
                    dateDraft =
                        value

                    timeZoneDraft =
                        timeZoneID
                        ?? TestudoTime
                            .deviceTimeZoneID

                    editingField =
                        field
                }
            )
        }
    }


    @ViewBuilder
    private func textRow(
        _ event: CalendarEvent,
        label: String,
        value: String?,
        field: EditableField,
        multiline: Bool = false
    ) -> some View {
        if editingField == field {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                if multiline {
                    TextEditor(
                        text:
                            $textDraft
                    )
                    .frame(
                        minHeight: 90
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 6
                        )
                        .stroke(
                            Color.secondary
                                .opacity(0.15)
                        )
                    }
                } else {
                    TextField(
                        label,
                        text:
                            $textDraft
                    )
                }

                CalendarEditActions(
                    cancel:
                        cancelEdit,
                    save: {
                        saveText(
                            event,
                            field:
                                field
                        )
                    }
                )
            }
        } else {
            CalendarPropertyRow(
                label:
                    label,
                value:
                    value ?? "",
                navigationDestination:
                    field == .notes
                    &&
                    !(value ?? "")
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                    ? .calendarEvent(
                        event.id
                    )
                    : nil,
                editable:
                    !store
                        .isReadOnlyCalendarEvent(
                            event
                        ),
                edit: {
                    beginText(
                        field,
                        value:
                            value ?? ""
                    )
                }
            )
        }
    }


    @ViewBuilder
    private func workLinksRow(
        _ event: CalendarEvent
    ) -> some View {
        let current =
            store.linkedWorkItems(
                forCalendarEventID:
                    event.id
            )
            .filter {
                $0.kind == .task
            }

        HierarchicalSelectionSummaryRow(
            label:
                "Tasks",
            selectedTitles:
                current.map(workName),
            selectedDestinations:
                current.map {
                    .work(
                        $0.id
                    )
                },
            selectorTitle:
                "Related Tasks",
            selectorMessage:
                "Tasks are shown in their real hierarchy: Task → Sub-task → deeper levels.",
            nodes:
                HierarchySelectionData
                    .taskNodes(
                        store:
                            store
                    ),
            initialSelection:
                Set(
                    current.map(\.id)
                ),
            buttonSystemImage:
                "plus.circle",
            onSave: {
                selection in

                store
                    .setCalendarEventWorkLinks(
                        calendarEventID:
                            event.id,
                        workItemIDs:
                            selection
                    )
            }
        )
    }


    @ViewBuilder
    private func themeLinksRow(
        _ event: CalendarEvent
    ) -> some View {
        let current =
            store.linkedThemes(
                forCalendarEventID:
                    event.id
            )

        HierarchicalSelectionSummaryRow(
            label:
                "Themes",
            selectedTitles:
                current.map(\.name),
            selectedDestinations:
                current.map {
                    .theme(
                        $0.id
                    )
                },
            selectorTitle:
                "Related Themes",
            selectorMessage:
                "Themes are shown in their real hierarchy: Theme → Sub-theme → deeper levels.",
            nodes:
                HierarchySelectionData
                    .themeNodes(
                        store:
                            store
                    ),
            initialSelection:
                Set(
                    current.map(\.id)
                ),
            buttonSystemImage:
                "plus.circle",
            onSave: {
                selection in

                store
                    .setCalendarEventThemeLinks(
                        calendarEventID:
                            event.id,
                        themeIDs:
                            selection
                    )
            }
        )
    }


    private func readonlyRow(
        label: String,
        value: String,
        dateDestination:
            Date? = nil
    ) -> some View {
        HStack(
            spacing: 14
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 120,
                    alignment: .leading
                )

            if let dateDestination {
                TestudoDateLink(
                    title:
                        value,
                    date:
                        dateDestination
                )
            } else {
                Text(value)
                    .textSelection(
                        .enabled
                    )
            }

            Spacer()
        }
        .font(.callout)
    }


    private func beginText(
        _ field: EditableField,
        value: String
    ) {
        textDraft =
            value

        errorMessage =
            nil

        editingField =
            field
    }


    private func saveText(
        _ event: CalendarEvent,
        field: EditableField
    ) {
        var updated =
            event

        switch field {
        case .title:
            updated.title =
                textDraft

        case .location:
            let cleaned =
                textDraft
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            updated.location =
                cleaned.isEmpty
                ? nil
                : cleaned

        case .notes:
            updated.notes =
                textDraft

        default:
            return
        }

        finish(
            store
                .updateCalendarEvent(
                    updated
                )
        )
    }


    private func finish(
        _ error: String?
    ) {
        errorMessage =
            error

        if error == nil {
            cancelEdit()
        }
    }


    private func cancelEdit() {
        editingField =
            nil

        errorMessage =
            nil
    }


    private func setBinding(
        _ id: UUID,
        set:
            Binding<Set<UUID>>
    ) -> Binding<Bool> {
        Binding(
            get: {
                set.wrappedValue
                    .contains(id)
            },
            set: {
                enabled in

                if enabled {
                    set.wrappedValue
                        .insert(id)
                } else {
                    set.wrappedValue
                        .remove(id)
                }
            }
        )
    }


    private var taskCandidates:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                $0.kind == .task
            }
            .sorted {
                workName($0)
                    .localizedCaseInsensitiveCompare(
                        workName($1)
                    )
                    == .orderedAscending
            }
    }


    private var themeCandidates:
        [Theme]
    {
        store.data.themes
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }


    private func workName(
        _ item: WorkItem
    ) -> String {
        if
            let title =
                item.title?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !title.isEmpty
        {
            return title
        }

        let body =
            item.body
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if !body.isEmpty {
            return String(
                body.prefix(70)
            )
        }

        return "Untitled Task"
    }


    private func dateDescription(
        _ date: Date,
        allDay: Bool,
        timeZoneID: String?
    ) -> String {
        if allDay {
            return date.formatted(
                date: .long,
                time: .omitted
            )
        }

        return TestudoTime
            .dateTime(
                date
            )
    }
}
