import SwiftUI

enum WorkListMode {
    case all
    case todo
    case inProgress
    case completed
    case timeline
}

struct TodayDashboardView: View {
    @EnvironmentObject
    private var store: DReportStore

    @Binding
    var selection: UUID?

    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    private var now: Date {
        Date()
    }

    private var startOfToday: Date {
        calendar.startOfDay(
            for: now
        )
    }

    private var startOfTomorrow: Date {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: startOfToday
        )!
    }

    private var endOfUpcomingWindow: Date {
        calendar.date(
            byAdding: .day,
            value: 8,
            to: startOfToday
        )!
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkColumnHeader(
                title: "Today",
                subtitle:
                    dashboardSubtitle
            )

            if allVisibleItems.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Nothing Needs Attention",
                        systemImage:
                            "checkmark.circle"
                    )
                } description: {
                    Text(
                        "There is nothing scheduled, due or logged for today."
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            } else {
                List(
                    selection: $selection
                ) {
                    dashboardSection(
                        "Needs Attention",
                        items:
                            needsAttention
                    )

                    dashboardSection(
                        "Today",
                        items:
                            todayItems
                    )

                    dashboardSection(
                        "In Progress",
                        items:
                            inProgress
                    )

                    dashboardSection(
                        "Upcoming",
                        items:
                            upcoming
                    )

                    dashboardSection(
                        "Done Today",
                        items:
                            doneToday
                    )

                    dashboardSection(
                        "Today's Log",
                        items:
                            todaysLog
                    )
                }
                .listStyle(.inset)
            }
        }
        .background(
            DReportStyle.contentBackground
        )
    }

    @ViewBuilder
    private func dashboardSection(
        _ title: String,
        items: [WorkItem]
    ) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    WorkGuideRow(
                        item: item,
                        context:
                            contextText(
                                for: item,
                                section: title
                            )
                    )
                    .tag(item.id)
                }
            } header: {
                HStack {
                    Text(title)

                    Spacer()

                    Text(
                        "\(items.count)"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .tertiary
                    )
                }
            }
        }
    }

    private var needsAttention:
        [WorkItem]
    {
        store.data.workItems
            .filter { item in
                if
                    item.kind == .task,
                    item.status != .completed,
                    let deadline =
                        item.deadlineAt,
                    deadline < startOfToday
                {
                    return true
                }

                if
                    item.kind != .task,
                    let reminder =
                        item.reminderAt,
                    reminder < now
                {
                    return true
                }

                return false
            }
            .sorted(
                by: priorityDateSort
            )
    }

    private var todayItems:
        [WorkItem]
    {
        let excluded =
            Set(
                needsAttention.map(\.id)
            )

        return store.data.workItems
            .filter { item in
                guard
                    !excluded.contains(
                        item.id
                    )
                else {
                    return false
                }

                if
                    item.kind == .task,
                    item.status != .completed,
                    let deadline =
                        item.deadlineAt,
                    isToday(deadline)
                {
                    return true
                }

                if
                    item.kind == .activity,
                    let eventDate =
                        item.scheduledAt,
                    isToday(eventDate)
                {
                    return true
                }

                if
                    item.kind != .task,
                    let reminder =
                        item.reminderAt,
                    isToday(reminder)
                {
                    return true
                }

                return false
            }
            .sorted(
                by: priorityDateSort
            )
    }

    private var inProgress:
        [WorkItem]
    {
        let excluded =
            Set(
                (
                    needsAttention
                    + todayItems
                )
                .map(\.id)
            )

        return store.data.workItems
            .filter {
                $0.kind == .task
                && $0.status
                    == .inProgress
                && !excluded.contains(
                    $0.id
                )
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }

    private var upcoming:
        [WorkItem]
    {
        let excluded =
            Set(
                (
                    needsAttention
                    + todayItems
                    + inProgress
                )
                .map(\.id)
            )

        return store.data.workItems
            .filter { item in
                guard
                    !excluded.contains(
                        item.id
                    )
                else {
                    return false
                }

                if
                    item.kind == .task,
                    item.status != .completed,
                    let deadline =
                        item.deadlineAt
                {
                    return (
                        deadline
                            >= startOfTomorrow
                        && deadline
                            < endOfUpcomingWindow
                    )
                }

                if
                    item.kind == .activity,
                    let eventDate =
                        item.scheduledAt
                {
                    return (
                        eventDate
                            >= startOfTomorrow
                        && eventDate
                            < endOfUpcomingWindow
                    )
                }

                if
                    item.kind != .task,
                    let reminder =
                        item.reminderAt
                {
                    return (
                        reminder
                            >= startOfTomorrow
                        && reminder
                            < endOfUpcomingWindow
                    )
                }

                return false
            }
            .sorted(
                by: priorityDateSort
            )
    }

    private var doneToday:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                $0.kind == .task
                && $0.status == .completed
                && (
                    $0.completedAt
                        .map(isToday)
                    ?? false
                )
            }
            .sorted {
                (
                    $0.completedAt
                    ?? $0.updatedAt
                )
                >
                (
                    $1.completedAt
                    ?? $1.updatedAt
                )
            }
    }

    private var todaysLog:
        [WorkItem]
    {
        let excluded =
            Set(
                (
                    needsAttention
                    + todayItems
                    + doneToday
                )
                .map(\.id)
            )

        return store.data.workItems
            .filter { item in
                guard
                    item.kind != .task,
                    !excluded.contains(
                        item.id
                    )
                else {
                    return false
                }

                let date =
                    item.loggedAt
                    ?? item.createdAt

                return isToday(date)
            }
            .sorted {
                (
                    $0.loggedAt
                    ?? $0.createdAt
                )
                >
                (
                    $1.loggedAt
                    ?? $1.createdAt
                )
            }
    }

    private var allVisibleItems:
        [WorkItem]
    {
        needsAttention
        + todayItems
        + inProgress
        + upcoming
        + doneToday
        + todaysLog
    }

    private var dashboardSubtitle:
        String
    {
        let actionCount =
            needsAttention.count
            + todayItems.count
            + inProgress.count

        if needsAttention.isEmpty {
            return
                "\(actionCount) active items"
        }

        return
            "\(needsAttention.count) need attention · \(actionCount) active"
    }

    private func isToday(
        _ date: Date
    ) -> Bool {
        calendar.isDateInToday(
            date
        )
    }

    private func priorityDate(
        for item: WorkItem
    ) -> Date {
        if
            item.kind == .task,
            let deadline =
                item.deadlineAt
        {
            return deadline
        }

        if
            let reminder =
                item.reminderAt
        {
            return reminder
        }

        if
            item.kind == .activity,
            let scheduled =
                item.scheduledAt
        {
            return scheduled
        }

        return item.updatedAt
    }

    private func priorityDateSort(
        _ lhs: WorkItem,
        _ rhs: WorkItem
    ) -> Bool {
        priorityDate(
            for: lhs
        )
        <
        priorityDate(
            for: rhs
        )
    }

    private func contextText(
        for item: WorkItem,
        section: String
    ) -> String? {
        if
            item.kind == .task,
            let deadline =
                item.deadlineAt
        {
            if deadline < startOfToday {
                let days =
                    calendar.dateComponents(
                        [.day],
                        from:
                            calendar.startOfDay(
                                for: deadline
                            ),
                        to: startOfToday
                    )
                    .day ?? 0

                return days == 1
                    ? "1 day overdue"
                    : "\(days) days overdue"
            }

            if isToday(deadline) {
                return "Due today"
            }

            if
                calendar.isDateInTomorrow(
                    deadline
                )
            {
                return "Due tomorrow"
            }

            return
                "Due \(deadline.formatted(date: .abbreviated, time: .omitted))"
        }

        if
            let reminder =
                item.reminderAt
        {
            if reminder < now {
                return
                    "Reminder \(relativeTime(reminder))"
            }

            return
                "Reminder \(DReportTime.displayTime(reminder, sourceTimeZoneID: item.reminderTimeZoneID))"
        }

        if
            item.kind == .activity,
            let eventDate =
                item.scheduledAt
        {
            if isToday(eventDate) {
                return
                    eventDate.formatted(
                        date: .omitted,
                        time: .shortened
                    )
            }

            if
                calendar.isDateInTomorrow(
                    eventDate
                )
            {
                return
                    "Tomorrow \(eventDate.formatted(date: .omitted, time: .shortened))"
            }

            return
                eventDate.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
        }

        if section == "In Progress" {
            return "In progress"
        }

        return nil
    }

    private func relativeTime(
        _ date: Date
    ) -> String {
        let formatter =
            RelativeDateTimeFormatter()

        formatter.unitsStyle =
            .full

        return formatter.localizedString(
            for: date,
            relativeTo: now
        )
    }
}

struct WorkListView: View {
    @EnvironmentObject
    private var store: DReportStore

    let mode: WorkListMode

    @Binding
    var selection: UUID?


    @State
    private var expandedTaskIDs:
        Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            WorkColumnHeader(
                title: title,
                subtitle:
                    "\(items.count) items"
            )

            if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage:
                        emptyIcon
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            } else if showsTaskHierarchy {
                List(
                    selection: $selection
                ) {
                    ForEach(
                        visibleTaskEntries
                    ) { entry in
                        HStack(
                            alignment: .top,
                            spacing: 4
                        ) {
                            if entry.hasChildren {
                                Button {
                                    toggleExpansion(
                                        entry.item.id
                                    )
                                } label: {
                                    Image(
                                        systemName:
                                            expandedTaskIDs
                                                .contains(
                                                    entry.item.id
                                                )
                                            ? "chevron.down"
                                            : "chevron.right"
                                    )
                                    .font(
                                        .system(
                                            size: 10,
                                            weight:
                                                .semibold
                                        )
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .frame(
                                        width: 14,
                                        height: 18
                                    )
                                    .contentShape(
                                        Rectangle()
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(
                                    expandedTaskIDs
                                        .contains(
                                            entry.item.id
                                        )
                                    ? "Collapse"
                                    : "Expand"
                                )
                            } else {
                                Color.clear
                                    .frame(
                                        width: 14,
                                        height: 18
                                    )
                            }

                            WorkGuideRow(
                                item:
                                    entry.item,
                                context:
                                    genericContext(
                                        entry.item
                                    )
                            )
                        }
                        .padding(
                            .leading,
                            indentation(
                                for:
                                    entry.depth
                            )
                        )
                        .tag(
                            entry.item.id
                        )
                    }
                }
                .listStyle(.inset)

            } else {
                List(
                    selection: $selection
                ) {
                    ForEach(items) { item in
                        WorkGuideRow(
                            item: item,
                            context:
                                genericContext(
                                    item
                                )
                        )
                        .tag(item.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(
            DReportStyle.contentBackground
        )
    }

    private struct TaskOutlineEntry:
        Identifiable
    {
        let item: WorkItem
        let depth: Int
        let hasChildren: Bool

        var id: UUID {
            item.id
        }
    }


    private var showsTaskHierarchy:
        Bool
    {
        switch mode {
        case .all:
            return true

        default:
            return false
        }
    }


    private var allTasks:
        [WorkItem]
    {
        store.data.workItems
            .filter {
                $0.kind == .task
            }
    }


    private var rootTasks:
        [WorkItem]
    {
        allTasks
            .filter {
                task in

                guard
                    let parentID =
                        task.parentWorkItemID
                else {
                    return true
                }

                // A task whose parent no longer exists, or whose
                // parent is not itself a Task, is treated as a root
                // so that it can never disappear from All Tasks.
                guard
                    let parent =
                        store.workItem(
                            id:
                                parentID
                        )
                else {
                    return true
                }

                return
                    parent.kind
                    != .task
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }


    private var visibleTaskEntries:
        [TaskOutlineEntry]
    {
        var result:
            [TaskOutlineEntry] = []

        for task in rootTasks {
            appendVisibleTask(
                task,
                depth:
                    0,
                to:
                    &result
            )
        }

        return result
    }


    private func appendVisibleTask(
        _ task: WorkItem,
        depth: Int,
        to result:
            inout [TaskOutlineEntry]
    ) {
        let children =
            childTasks(
                of:
                    task.id
            )

        result.append(
            TaskOutlineEntry(
                item:
                    task,
                depth:
                    depth,
                hasChildren:
                    !children.isEmpty
            )
        )

        guard
            expandedTaskIDs
                .contains(
                    task.id
                )
        else {
            return
        }

        for child in children {
            appendVisibleTask(
                child,
                depth:
                    depth + 1,
                to:
                    &result
            )
        }
    }


    private func childTasks(
        of parentID: UUID
    ) -> [WorkItem] {
        allTasks
            .filter {
                $0.parentWorkItemID
                    == parentID
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }


    private func toggleExpansion(
        _ id: UUID
    ) {
        if expandedTaskIDs.contains(id) {
            expandedTaskIDs.remove(id)
        } else {
            expandedTaskIDs.insert(id)
        }
    }


    private func indentation(
        for depth: Int
    ) -> CGFloat {
        // Small incremental indentation.
        // Cap the total so deeply nested tasks retain useful width.
        min(
            CGFloat(depth) * 12,
            84
        )
    }


    private var items:
        [WorkItem]
    {
        switch mode {
        case .all:
            return store.data.workItems
                .filter {
                    $0.kind == .task
                }
                .sorted {
                    $0.updatedAt
                        > $1.updatedAt
                }

        case .todo:
            return tasks(
                with: .todo
            )

        case .inProgress:
            return tasks(
                with: .inProgress
            )

        case .completed:
            return tasks(
                with: .completed
            )

        case .timeline:
            return store.data.workItems
                .sorted {
                    relevantDate($0)
                        > relevantDate($1)
                }
        }
    }

    private func tasks(
        with status: TaskStatus
    ) -> [WorkItem] {
        store.data.workItems
            .filter {
                $0.kind == .task
                && $0.status == status
            }
            .sorted {
                $0.updatedAt
                    > $1.updatedAt
            }
    }

    private func relevantDate(
        _ item: WorkItem
    ) -> Date {
        item.loggedAt
        ?? item.completedAt
        ?? item.startedAt
        ?? item.scheduledAt
        ?? item.updatedAt
    }

    private var title: String {
        switch mode {
        case .all:
            return "All Tasks"
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .timeline:
            return "Timeline"
        }
    }

    private var emptyTitle: String {
        switch mode {
        case .all:
            return "No Tasks"
        case .todo:
            return "Nothing To Do"
        case .inProgress:
            return "Nothing In Progress"
        case .completed:
            return "No Completed Tasks"
        case .timeline:
            return "No Activity Yet"
        }
    }

    private var emptyIcon: String {
        switch mode {
        case .all:
            return "list.bullet"
        case .todo:
            return "circle"
        case .inProgress:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .timeline:
            return "list.bullet.rectangle"
        }
    }

    private func genericContext(
        _ item: WorkItem
    ) -> String? {
        if
            item.kind == .task,
            let deadline =
                item.deadlineAt
        {
            return
                "Due \(deadline.formatted(date: .abbreviated, time: .omitted))"
        }

        if
            item.kind != .task,
            let reminder =
                item.reminderAt
        {
            return
                "Reminder \(DReportTime.displayDateTime(reminder, sourceTimeZoneID: item.reminderTimeZoneID))"
        }

        if
            item.kind == .activity,
            let scheduled =
                item.scheduledAt
        {
            return scheduled.formatted(
                date: .abbreviated,
                time: .shortened
            )
        }

        return nil
    }
}

struct WorkColumnHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(title)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(
            .horizontal,
            16
        )
        .padding(
            .top,
            2
        )
        .padding(
            .bottom,
            4
        )
    }
}

struct WorkGuideRow: View {
    @EnvironmentObject
    private var store: DReportStore

    let item: WorkItem
    let context: String?

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            Image(
                systemName: icon
            )
            .font(
                .system(
                    size: 13
                )
            )
            .frame(
                width: 16,
                height: 18
            )
            .foregroundStyle(
                iconStyle
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                HStack(
                    alignment: .firstTextBaseline
                ) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Spacer(
                        minLength: 6
                    )

                    if let context {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 7) {
                    if
                        let theme =
                            store.theme(
                                id:
                                    item.themeID
                            )
                    {
                        Text(theme.name)
                    }

                    Text(typeLabel)

                    if
                        item.kind == .task,
                        let status =
                            item.status
                    {
                        Text(
                            status.displayName
                        )
                    }
                }
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var title: String {
        if
            let title = item.title,
            !title
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return typeLabel
    }

    private var typeLabel: String {
        switch item.kind {
        case .task:
            return "Task"
        case .note:
            return "Note"
        case .activity:
            return "Event"
        }
    }

    private var icon: String {
        switch item.kind {
        case .task:
            switch item.status {
            case .completed:
                return "checkmark.circle"
            case .inProgress:
                return "clock"
            case .todo, nil:
                return "circle"
            }

        case .note:
            if item.reminderAt != nil {
                return "bell"
            }

            return "note.text"

        case .activity:
            return "calendar"
        }
    }

    private var iconStyle:
        HierarchicalShapeStyle
    {
        .primary
    }
}

struct WorkItemDetailView: View {
    @EnvironmentObject
    private var store: DReportStore

    let itemID: UUID

    @Binding
    var selectedWorkItemID:
        UUID?

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft = ""

    @State
    private var uuidDraft:
        UUID?

    @State
    private var statusDraft:
        TaskStatus = .todo

    @State
    private var dateDraft =
        Date()

    @State
    private var dateTimeZoneDraft =
        DReportTime.deviceTimeZoneID

    @State
    private var dateEnabledDraft =
        true

    @State
    private var relationshipRoleDraft:
        WorkRelationshipRole =
        .relatedTo

    @State
    private var relationshipEntityDraft:
        UUID?


    @State
    private var showingRelationshipComposer =
        false

    @State
    private var newRelationshipRoleDraft:
        WorkRelationshipRole =
        .relatedTo

    @State
    private var newRelationshipEntityDraft:
        UUID?

    @State
    private var newRelationshipInheritedByChildren =
        true

    @State
    private var showingChildComposer =
        false

    @State
    private var childKindDraft:
        WorkItemKind = .task

    @State
    private var childTitleDraft =
        ""

    @State
    private var childBodyDraft =
        ""

    @State
    private var childHasDeadline =
        false

    @State
    private var childDeadlineDraft =
        Date()

    @State
    private var childDeadlineTimeZoneID =
        DReportTime.deviceTimeZoneID

    @State
    private var childHasReminder =
        false

    @State
    private var childReminderDraft =
        Date()

    @State
    private var childReminderTimeZoneID =
        DReportTime.deviceTimeZoneID

    @State
    private var childOccurredAtDraft =
        Date()

    @State
    private var childOccurredTimeZoneID =
        DReportTime.deviceTimeZoneID

    @State
    private var childErrorMessage:
        String?

    @State
    private var errorMessage:
        String?

    private enum EditableField:
        Hashable
    {
        case title
        case body
        case theme
        case parent
        case status
        case deadline
        case reminder
        case eventDate
        case relationship(UUID)
    }

    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let item =
                    store.workItem(
                        id: itemID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 28
                    ) {
                        header(item)

                        descriptionSection(
                            item
                        )

                        detailsSection(
                            item
                        )

                        hierarchySection(
                            item
                        )

                        childrenSection(
                            item
                        )

                        relationshipsSection(
                            item
                        )

                        historySection(
                            item
                        )
                    }
                    .padding(
                        .horizontal,
                        28
                    )
                    .padding(
                        .bottom,
                        28
                    )
                    .padding(
                        .top,
                        4
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
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .background(
                    DReportStyle
                        .contentBackground
                )
            } else {
                ContentUnavailableView(
                    "Item Not Found",
                    systemImage:
                        "questionmark.circle"
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            DReportStyle
                .contentBackground
        )
    }

    private func header(
        _ item: WorkItem
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    largeIcon(
                        item
                    )
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                if
                    editingField
                        == .title
                {
                    TextField(
                        "Title",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    InlineEditActions(
                        onCancel: cancelEdit,
                        onSave: {
                            saveTitle(
                                item
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(
                            displayTitle(
                                item
                            )
                        )
                        .font(.title2)
                        .fontWeight(
                            .semibold
                        )
                        .textSelection(
                            .enabled
                        )

                        InlineEditButton {
                            beginTextEdit(
                                .title,
                                value:
                                    item.title
                                    ?? ""
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(
                        typeLabel(
                            item
                        )
                    )

                    if
                        let theme =
                            store.theme(
                                id:
                                    item.themeID
                            )
                    {
                        Text("·")
                        Text(theme.name)
                    }

                    if
                        item.kind
                            == .task,
                        let status =
                            item.status
                    {
                        Text("·")
                        Text(
                            status.displayName
                        )
                    }
                }
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func descriptionSection(
        _ item: WorkItem
    ) -> some View {
        InspectorSection(
            title: "Description"
        ) {
            if
                editingField
                    == .body
            {
                TextEditor(
                    text:
                        $textDraft
                )
                .frame(
                    minHeight: 130
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 6
                    )
                    .stroke(
                        Color.secondary
                            .opacity(0.18)
                    )
                }

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveBody(
                            item
                        )
                    }
                )
            } else {
                HStack(
                    alignment: .top,
                    spacing: 10
                ) {
                    Group {
                        if
                            item.body
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                                .isEmpty
                        {
                            Text(
                                "No description"
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                        } else {
                            Text(
                                item.body
                            )
                            .textSelection(
                                .enabled
                            )
                        }
                    }

                    Spacer()

                    InlineEditButton {
                        beginTextEdit(
                            .body,
                            value:
                                item.body
                        )
                    }
                }
            }
        }
    }

    private func detailsSection(
        _ item: WorkItem
    ) -> some View {
        InspectorSection(
            title: "Details"
        ) {
            VStack(spacing: 9) {
                themeRow(item)

                parentRow(item)

                if
                    item.kind
                        == .task
                {
                    statusRow(item)
                    deadlineRow(item)
                }

                if
                    item.kind
                        == .note
                {
                    reminderRow(item)
                }

                if
                    item.kind
                        == .activity
                {
                    occurredRow(item)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(
                        .red
                    )
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func themeRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .theme
        {
            InlineEditorRow(
                label: "Theme"
            ) {
                Picker(
                    "",
                    selection:
                        $uuidDraft
                ) {
                    Text("No Theme")
                        .tag(
                            Optional<UUID>.none
                        )

                    ForEach(
                        sortedThemes
                    ) { theme in
                        Text(theme.name)
                            .tag(
                                Optional(
                                    theme.id
                                )
                            )
                    }
                }
                .labelsHidden()
                .frame(
                    maxWidth: 280
                )

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveTheme(
                            item
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Theme",
                value:
                    item.themeID
                        .flatMap {
                            store.theme(
                                id: $0
                            )?.name
                        }
                    ?? "No Theme",
                onEdit: {
                    uuidDraft =
                        item.themeID

                    editingField =
                        .theme
                }
            )
        }
    }

    @ViewBuilder
    private func parentRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .parent
        {
            InlineEditorRow(
                label: "Parent"
            ) {
                Picker(
                    "",
                    selection:
                        $uuidDraft
                ) {
                    Text("No Parent")
                        .tag(
                            Optional<UUID>
                                .none
                        )

                    ForEach(
                        availableParentTasks(
                            for:
                                item.id
                        )
                    ) { parent in
                        Text(
                            displayTitle(
                                parent
                            )
                        )
                        .tag(
                            Optional(
                                parent.id
                            )
                        )
                    }
                }
                .labelsHidden()
                .frame(
                    maxWidth: 300
                )

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveParent(
                            item
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Parent",
                value:
                    parentName(
                        item
                    ),
                onEdit: {
                    uuidDraft =
                        item
                            .parentWorkItemID

                    editingField =
                        .parent
                }
            )
        }
    }

    @ViewBuilder
    private func statusRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .status
        {
            InlineEditorRow(
                label: "Status"
            ) {
                Picker(
                    "",
                    selection:
                        $statusDraft
                ) {
                    Text("To Do")
                        .tag(
                            TaskStatus.todo
                        )

                    Text("In Progress")
                        .tag(
                            TaskStatus
                                .inProgress
                        )

                    Text("Completed")
                        .tag(
                            TaskStatus
                                .completed
                        )
                }
                .labelsHidden()
                .frame(
                    maxWidth: 220
                )

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveStatus(
                            item
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Status",
                value:
                    item.status?
                        .displayName
                    ?? "To Do",
                onEdit: {
                    statusDraft =
                        item.status
                        ?? .todo

                    editingField =
                        .status
                }
            )
        }
    }

    @ViewBuilder
    private func deadlineRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .deadline
        {
            dateEditorRow(
                label: "Deadline",
                field: .deadline,
                item: item
            )
        } else {
            EditableValueRow(
                label: "Deadline",
                value:
                    item.deadlineAt
                        .map {
                            DReportTime
                                .displayDateTime(
                                    $0,
                                    sourceTimeZoneID:
                                        item.deadlineTimeZoneID
                                )
                        }
                    ?? "None",
                onEdit: {
                    beginDateEdit(
                        .deadline,
                        date:
                            item.deadlineAt,
                        timeZoneID:
                            item.deadlineTimeZoneID
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func reminderRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .reminder
        {
            dateEditorRow(
                label: "Reminder",
                field: .reminder,
                item: item
            )
        } else {
            EditableValueRow(
                label: "Reminder",
                value:
                    item.reminderAt
                        .map {
                            DReportTime
                                .displayDateTime(
                                    $0,
                                    sourceTimeZoneID:
                                        item.reminderTimeZoneID
                                )
                        }
                    ?? "None",
                onEdit: {
                    beginDateEdit(
                        .reminder,
                        date:
                            item.reminderAt,
                        timeZoneID:
                            item.reminderTimeZoneID
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func occurredRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .eventDate
        {
            dateEditorRow(
                label: "Occurred",
                field: .eventDate,
                item: item
            )
        } else {
            EditableValueRow(
                label: "Occurred",
                value:
                    item.loggedAt
                        .map {
                            DReportTime
                                .displayDateTime(
                                    $0,
                                    sourceTimeZoneID:
                                        item.loggedTimeZoneID
                                )
                        }
                    ?? "Unknown",
                onEdit: {
                    beginDateEdit(
                        .eventDate,
                        date:
                            item.loggedAt,
                        timeZoneID:
                            item.loggedTimeZoneID
                    )
                }
            )
        }
    }

    private func dateEditorRow(
        label: String,
        field: EditableField,
        item: WorkItem
    ) -> some View {
        InlineEditorRow(
            label: label
        ) {
            Toggle(
                "Set",
                isOn:
                    $dateEnabledDraft
            )
            .toggleStyle(
                .checkbox
            )

            if dateEnabledDraft {
                TimeZoneAwareDateEditor(
                    label: "",
                    date:
                        $dateDraft,
                    timeZoneID:
                        $dateTimeZoneDraft
                )
                .frame(
                    maxWidth: 330
                )
            }

            InlineEditActions(
                onCancel:
                    cancelEdit,
                onSave: {
                    saveDate(
                        field,
                        item: item
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func hierarchySection(
        _ item: WorkItem
    ) -> some View {
        let path =
            hierarchyPath(
                for: item
            )

        if path.count > 1 {
            InspectorSection(
                title: "Location"
            ) {
                Text(
                    path.joined(
                        separator:
                            "  ›  "
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .textSelection(
                    .enabled
                )
            }
        }
    }

    @ViewBuilder
    private func childrenSection(
        _ item: WorkItem
    ) -> some View {
        let children =
            childItems(
                of: item.id
            )

        if item.kind == .task {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                HStack {
                    Text("Contains")
                        .font(.headline)

                    Spacer()

                    Menu {
                        Button {
                            beginChildComposer(
                                .task
                            )
                        } label: {
                            Label(
                                "Sub-task",
                                systemImage:
                                    "circle"
                            )
                        }

                        Button {
                            beginChildComposer(
                                .note
                            )
                        } label: {
                            Label(
                                "Note",
                                systemImage:
                                    "note.text"
                            )
                        }

                        Button {
                            beginChildComposer(
                                .activity
                            )
                        } label: {
                            Label(
                                "Event",
                                systemImage:
                                    "clock.arrow.circlepath"
                            )
                        }
                    } label: {
                        Image(
                            systemName:
                                "plus.circle"
                        )
                        .font(
                            .system(
                                size: 13,
                                weight:
                                    .medium
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            width: 24,
                            height: 24
                        )
                    }
                    .menuStyle(
                        .borderlessButton
                    )
                    .menuIndicator(
                        .hidden
                    )
                    .help(
                        "Add to this task"
                    )
                }

                if showingChildComposer {
                    childComposer(
                        parent: item
                    )
                }

                if children.isEmpty
                    && !showingChildComposer
                {
                    Text(
                        "No sub-tasks, notes or events."
                    )
                    .font(.callout)
                    .foregroundStyle(
                        .tertiary
                    )
                }

                if !children.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        ForEach(
                            children
                        ) { child in
                            Button {
                                cancelEdit()

                                selectedWorkItemID =
                                    child.id
                            } label: {
                                HStack(
                                    spacing: 9
                                ) {
                                    Image(
                                        systemName:
                                            childIcon(
                                                child
                                            )
                                    )
                                    .frame(
                                        width: 18
                                    )

                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing: 2
                                    ) {
                                        Text(
                                            displayTitle(
                                                child
                                            )
                                        )

                                        if
                                            child.kind
                                                == .activity,
                                            let occurred =
                                                child.loggedAt
                                        {
                                            Text(
                                                "Occurred \(DReportTime.displayDateTime(occurred, sourceTimeZoneID: child.loggedTimeZoneID))"
                                            )
                                            .font(
                                                .caption2
                                            )
                                            .foregroundStyle(
                                                .secondary
                                            )
                                        }
                                    }

                                    Spacer()

                                    Text(
                                        childTypeLabel(
                                            child
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                                }
                                .padding(
                                    .vertical,
                                    5
                                )
                                .contentShape(
                                    Rectangle()
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                }
            }
        }
    }

    private func childComposer(
        parent: WorkItem
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Label(
                    childComposerTitle,
                    systemImage:
                        childComposerIcon
                )
                .font(.callout)
                .fontWeight(.medium)

                Spacer()
            }

            TextField(
                childKindDraft == .note
                ? "Title (optional)"
                : "Title",
                text:
                    $childTitleDraft
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    childKindDraft == .note
                    ? "Note"
                    : (
                        childKindDraft
                            == .activity
                        ? "What happened?"
                        : "Description"
                    )
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                TextEditor(
                    text:
                        $childBodyDraft
                )
                .frame(
                    minHeight: 72
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

            if childKindDraft == .task {
                Toggle(
                    "Set deadline",
                    isOn:
                        $childHasDeadline
                )
                .toggleStyle(
                    .checkbox
                )

                if childHasDeadline {
                    TimeZoneAwareDateEditor(
                        label: "Deadline",
                        date:
                            $childDeadlineDraft,
                        timeZoneID:
                            $childDeadlineTimeZoneID
                    )
                }
            }

            if childKindDraft == .note {
                Toggle(
                    "Set reminder",
                    isOn:
                        $childHasReminder
                )
                .toggleStyle(
                    .checkbox
                )

                if childHasReminder {
                    TimeZoneAwareDateEditor(
                        label: "Reminder",
                        date:
                            $childReminderDraft,
                        timeZoneID:
                            $childReminderTimeZoneID
                    )
                }
            }

            if childKindDraft == .activity {
                TimeZoneAwareDateEditor(
                    label: "Occurred",
                    date:
                        $childOccurredAtDraft,
                    timeZoneID:
                        $childOccurredTimeZoneID
                )

                Text(
                    "Events record something that happened. They are not calendar appointments."
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            if let childErrorMessage {
                Text(
                    childErrorMessage
                )
                .font(.caption)
                .foregroundStyle(
                    .red
                )
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    cancelChildComposer()
                }
                .buttonStyle(
                    .borderless
                )

                Button("Add") {
                    addChild(
                        to: parent
                    )
                }
                .buttonStyle(
                    .borderless
                )
                .fontWeight(
                    .medium
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(12)
        .background(
            Color.primary
                .opacity(0.025)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8
            )
        )
    }

    private func beginChildComposer(
        _ kind: WorkItemKind
    ) {
        cancelEdit()

        childKindDraft =
            kind

        childTitleDraft =
            ""

        childBodyDraft =
            ""

        childHasDeadline =
            false

        childDeadlineDraft =
            Calendar.autoupdatingCurrent.date(
                byAdding: .day,
                value: 1,
                to: Date()
            )
            ?? Date()

        childHasReminder =
            false

        childReminderDraft =
            Calendar.autoupdatingCurrent.date(
                byAdding: .hour,
                value: 1,
                to: Date()
            )
            ?? Date()

        childOccurredAtDraft =
            Date()

        childDeadlineTimeZoneID =
            DReportTime.deviceTimeZoneID

        childReminderTimeZoneID =
            DReportTime.deviceTimeZoneID

        childOccurredTimeZoneID =
            DReportTime.deviceTimeZoneID

        childErrorMessage =
            nil

        showingChildComposer =
            true
    }

    private func cancelChildComposer() {
        showingChildComposer =
            false

        childErrorMessage =
            nil

        childTitleDraft =
            ""

        childBodyDraft =
            ""
    }

    private func addChild(
        to parent: WorkItem
    ) {
        let result =
            store.createChildWorkItem(
                parentTaskID:
                    parent.id,
                kind:
                    childKindDraft,
                title:
                    childTitleDraft,
                body:
                    childBodyDraft,
                deadlineAt:
                    childKindDraft
                        == .task
                    && childHasDeadline
                    ? childDeadlineDraft
                    : nil,
                reminderAt:
                    childKindDraft
                        == .note
                    && childHasReminder
                    ? childReminderDraft
                    : nil,
                occurredAt:
                    childKindDraft
                        == .activity
                    ? childOccurredAtDraft
                    : nil,
                deadlineTimeZoneID:
                    childKindDraft
                        == .task
                    && childHasDeadline
                    ? childDeadlineTimeZoneID
                    : nil,
                reminderTimeZoneID:
                    childKindDraft
                        == .note
                    && childHasReminder
                    ? childReminderTimeZoneID
                    : nil,
                occurredTimeZoneID:
                    childKindDraft
                        == .activity
                    ? childOccurredTimeZoneID
                    : nil
            )

        if let error = result.error {
            childErrorMessage =
                error
            return
        }

        cancelChildComposer()
    }

    private var childComposerTitle:
        String
    {
        switch childKindDraft {
        case .task:
            return "New Sub-task"

        case .note:
            return "New Note"

        case .activity:
            return "New Event"
        }
    }

    private var childComposerIcon:
        String
    {
        switch childKindDraft {
        case .task:
            return "circle"

        case .note:
            return "note.text"

        case .activity:
            return "clock.arrow.circlepath"
        }
    }

    private func childTypeLabel(
        _ item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            return "Sub-task"

        case .note:
            return "Note"

        case .activity:
            return "Event"
        }
    }

    private func childIcon(
        _ item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            switch item.status {
            case .completed:
                return "checkmark.circle"

            case .inProgress:
                return "clock"

            case .todo,
                 nil:
                return "circle"
            }

        case .note:
            return "note.text"

        case .activity:
            return "clock.arrow.circlepath"
        }
    }

    @ViewBuilder
    private func relationshipsSection(
        _ item: WorkItem
    ) -> some View {
        InspectorSection(
            title:
                "Related People & Organizations"
        ) {
            VStack(
                alignment: .leading,
                spacing: 11
            ) {
                ForEach(
                    WorkRelationshipRole
                        .allCases
                ) { role in
                    relationshipGroupRow(
                        item:
                            item,
                        role:
                            role
                    )
                }
            }
        }
    }


    @ViewBuilder
    private func relationshipGroupRow(
        item: WorkItem,
        role: WorkRelationshipRole
    ) -> some View {
        let relationships =
            relationships(
                for:
                    item.id,
                role:
                    role
            )

        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing: 12
            ) {
                HStack(
                    spacing: 5
                ) {
                    Text(
                        role.displayName
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Button {
                        beginAddingRelationship(
                            role:
                                role
                        )
                    } label: {
                        Image(
                            systemName:
                                "plus.circle"
                        )
                        .font(
                            .system(
                                size: 12,
                                weight:
                                    .regular
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            width: 17,
                            height: 17
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .help(
                        "Add \(role.displayName)"
                    )
                }
                .frame(
                    width: 145,
                    alignment: .leading
                )

                if relationships.isEmpty {
                    Text("—")
                        .foregroundStyle(
                            .tertiary
                        )
                } else {
                    Text(
                        relationshipNames(
                            relationships
                        )
                    )
                    .textSelection(
                        .enabled
                    )
                }

                Spacer()

                if !relationships.isEmpty {
                    Menu {
                        ForEach(
                            relationships
                        ) { relationship in

                            Menu(
                                entityName(
                                    for:
                                        relationship
                                )
                            ) {
                                Button(
                                    "Edit"
                                ) {
                                    beginEditingRelationship(
                                        relationship
                                    )
                                }

                                Divider()

                                Button(
                                    "Remove",
                                    role:
                                        .destructive
                                ) {
                                    store
                                        .removeWorkRelationship(
                                            relationshipID:
                                                relationship.id
                                        )

                                    if
                                        editingField
                                            == .relationship(
                                                relationship.id
                                            )
                                    {
                                        cancelEdit()
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(
                            systemName:
                                "pencil"
                        )
                        .font(
                            .system(
                                size: 10,
                                weight:
                                    .medium
                            )
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                        .frame(
                            width: 20,
                            height: 20
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .menuStyle(
                        .borderlessButton
                    )
                    .fixedSize()
                    .help(
                        "Edit relationships"
                    )
                }
            }
            .font(.callout)

            if
                showingRelationshipComposer,
                newRelationshipRoleDraft
                    == role
            {
                relationshipAddComposer(
                    item:
                        item,
                    role:
                        role
                )
            }

            ForEach(
                relationships
            ) { relationship in
                if
                    editingField
                        == .relationship(
                            relationship.id
                        )
                {
                    relationshipRow(
                        relationship
                    )
                    .padding(
                        .leading,
                        157
                    )
                }
            }
        }
    }


    @ViewBuilder
    private func relationshipAddComposer(
        item: WorkItem,
        role: WorkRelationshipRole
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 9
        ) {
            HStack(
                spacing: 10
            ) {
                Picker(
                    "",
                    selection:
                        $newRelationshipEntityDraft
                ) {
                    Text(
                        "Choose person or organization…"
                    )
                    .tag(
                        Optional<UUID>
                            .none
                    )

                    ForEach(
                        sortedEntities
                    ) { entity in
                        Text(
                            entity.name
                        )
                        .tag(
                            Optional(
                                entity.id
                            )
                        )
                    }
                }
                .labelsHidden()
                .frame(
                    maxWidth: 330
                )

                Spacer()
            }

            Toggle(
                "Inherited by child items",
                isOn:
                    $newRelationshipInheritedByChildren
            )
            .font(.caption)

            if let errorMessage {
                Text(
                    errorMessage
                )
                .font(.caption)
                .foregroundStyle(
                    .red
                )
            }

            HStack {
                Spacer()

                Button(
                    "Cancel"
                ) {
                    cancelAddingRelationship()
                }
                .buttonStyle(
                    .borderless
                )

                Button(
                    "Add"
                ) {
                    addRelationship(
                        to:
                            item,
                        role:
                            role
                    )
                }
                .buttonStyle(
                    .borderless
                )
                .fontWeight(
                    .medium
                )
                .disabled(
                    newRelationshipEntityDraft
                        == nil
                )
            }
        }
        .padding(
            .leading,
            157
        )
        .padding(
            .vertical,
            3
        )
    }


    private func relationships(
        for workItemID: UUID,
        role: WorkRelationshipRole
    ) -> [WorkEntityRelationship] {
        store.data
            .workEntityRelationships
            .filter {
                $0.workItemID
                    == workItemID
                && $0.role
                    == role
            }
            .sorted {
                entityName(
                    for:
                        $0
                )
                .localizedCaseInsensitiveCompare(
                    entityName(
                        for:
                            $1
                    )
                )
                == .orderedAscending
            }
    }


    private func relationshipNames(
        _ relationships:
            [WorkEntityRelationship]
    ) -> String {
        relationships
            .map {
                entityName(
                    for:
                        $0
                )
            }
            .joined(
                separator:
                    ", "
            )
    }


    private func entityName(
        for relationship:
            WorkEntityRelationship
    ) -> String {
        store.entity(
            id:
                relationship.entityID
        )?.name
        ?? "Unknown"
    }


    private func beginAddingRelationship(
        role:
            WorkRelationshipRole
    ) {
        cancelEdit()

        newRelationshipRoleDraft =
            role

        newRelationshipEntityDraft =
            nil

        newRelationshipInheritedByChildren =
            true

        errorMessage =
            nil

        showingRelationshipComposer =
            true
    }


    private func cancelAddingRelationship() {
        showingRelationshipComposer =
            false

        newRelationshipEntityDraft =
            nil

        newRelationshipInheritedByChildren =
            true

        errorMessage =
            nil
    }


    private func addRelationship(
        to item:
            WorkItem,
        role:
            WorkRelationshipRole
    ) {
        guard
            let entityID =
                newRelationshipEntityDraft
        else {
            errorMessage =
                "Select a person or organization."
            return
        }

        let error =
            store.addWorkRelationship(
                workItemID:
                    item.id,
                entityID:
                    entityID,
                role:
                    role,
                inheritedByChildren:
                    newRelationshipInheritedByChildren
            )

        if let error {
            errorMessage =
                error
            return
        }

        showingRelationshipComposer =
            false

        newRelationshipEntityDraft =
            nil

        newRelationshipInheritedByChildren =
            true

        errorMessage =
            nil
    }


    private func beginEditingRelationship(
        _ relationship:
            WorkEntityRelationship
    ) {
        showingRelationshipComposer =
            false

        errorMessage =
            nil

        relationshipRoleDraft =
            relationship.role

        relationshipEntityDraft =
            relationship.entityID

        editingField =
            .relationship(
                relationship.id
            )
    }


    @ViewBuilder
    private func relationshipRow(
        _ relationship:
            WorkEntityRelationship
    ) -> some View {
        if
            editingField
                == .relationship(
                    relationship.id
                )
        {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Picker(
                        "",
                        selection:
                            $relationshipRoleDraft
                    ) {
                        relationshipRoleOptions
                    }
                    .labelsHidden()
                    .frame(
                        width: 140
                    )

                    Picker(
                        "",
                        selection:
                            $relationshipEntityDraft
                    ) {
                        ForEach(
                            sortedEntities
                        ) { entity in
                            Text(
                                entity.name
                            )
                            .tag(
                                Optional(
                                    entity.id
                                )
                            )
                        }
                    }
                    .labelsHidden()

                    Spacer()
                }

                HStack {
                    Button(
                        "Remove",
                        role:
                            .destructive
                    ) {
                        store
                            .removeWorkRelationship(
                                relationshipID:
                                    relationship.id
                            )

                        cancelEdit()
                    }

                    Spacer()

                    InlineEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveRelationship(
                                relationship
                            )
                        }
                    )
                }
            }
            .padding(.vertical, 3)
        } else {
            HStack(
                alignment:
                    .firstTextBaseline,
                spacing: 16
            ) {
                Text(
                    relationshipLabel(
                        relationship.role
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 110,
                    alignment: .leading
                )

                Text(
                    store.entity(
                        id:
                            relationship
                                .entityID
                    )?.name
                    ?? "Unknown"
                )

                Spacer()

                InlineEditButton {
                    showingRelationshipComposer =
                        false

                    errorMessage =
                        nil

                    relationshipRoleDraft =
                        relationship.role

                    relationshipEntityDraft =
                        relationship.entityID

                    editingField =
                        .relationship(
                            relationship.id
                        )
                }
            }
            .font(.callout)
        }
    }

    private var relationshipRoleOptions:
        some View
    {
        Group {
            Text("For")
                .tag(
                    WorkRelationshipRole
                        .forWhom
                )

            Text("Requested by")
                .tag(
                    WorkRelationshipRole
                        .requestedBy
                )

            Text("With")
                .tag(
                    WorkRelationshipRole
                        .with
                )

            Text("Assigned to")
                .tag(
                    WorkRelationshipRole
                        .assignedTo
                )

            Text("Related to")
                .tag(
                    WorkRelationshipRole
                        .relatedTo
                )
        }
    }

    private func historySection(
        _ item: WorkItem
    ) -> some View {
        let logEntries =
            taskLogEntries(
                for: item
            )

        return InspectorSection(
            title: "History"
        ) {
            VStack(
                alignment: .leading,
                spacing: 9
            ) {
                ReadOnlyInspectorRow(
                    label: "Created",
                    value:
                        DReportTime
                            .displayDateTime(
                                item.createdAt,
                                sourceTimeZoneID:
                                    item.createdTimeZoneID
                            )
                )

                ReadOnlyInspectorRow(
                    label: "Updated",
                    value:
                        DReportTime
                            .displayDateTime(
                                item.updatedAt,
                                sourceTimeZoneID:
                                    item.updatedTimeZoneID
                            )
                )

                if
                    let started =
                        item.startedAt
                {
                    ReadOnlyInspectorRow(
                        label: "Started",
                        value:
                            DReportTime
                                .displayDateTime(
                                    started,
                                    sourceTimeZoneID:
                                        item.startedTimeZoneID
                                )
                    )
                }

                if
                    let completed =
                        item.completedAt
                {
                    ReadOnlyInspectorRow(
                        label:
                            "Completed",
                        value:
                            DReportTime
                                .displayDateTime(
                                    completed,
                                    sourceTimeZoneID:
                                        item.completedTimeZoneID
                                )
                    )
                }

                if
                    item.kind
                        == .activity,
                    let logged =
                        item.loggedAt
                {
                    ReadOnlyInspectorRow(
                        label: "Occurred",
                        value:
                            DReportTime
                                .displayDateTime(
                                    logged,
                                    sourceTimeZoneID:
                                        item.loggedTimeZoneID
                                )
                    )
                }

                if !logEntries.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {
                        Text("Log")
                            .font(
                                .subheadline
                            )
                            .fontWeight(
                                .semibold
                            )
                            .padding(
                                .top,
                                10
                            )

                        ForEach(
                            logEntries
                        ) { entry in
                            HStack(
                                alignment: .top,
                                spacing: 10
                            ) {
                                Image(
                                    systemName:
                                        entry.icon
                                )
                                .font(
                                    .system(
                                        size: 11,
                                        weight:
                                            .medium
                                    )
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                                .frame(
                                    width: 17,
                                    height: 17
                                )

                                VStack(
                                    alignment:
                                        .leading,
                                    spacing: 2
                                ) {
                                    Text(
                                        entry.text
                                    )
                                    .font(
                                        .callout
                                    )

                                    if
                                        let detail =
                                            entry.detail,
                                        !detail.isEmpty
                                    {
                                        Text(
                                            detail
                                        )
                                        .font(
                                            .caption
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                        .lineLimit(3)
                                    }
                                }

                                Spacer(
                                    minLength: 12
                                )

                                Text(
                                    DReportTime
                                        .displayDateTime(
                                            entry.timestamp,
                                            sourceTimeZoneID:
                                                entry.timeZoneID
                                        )
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                                .multilineTextAlignment(
                                    .trailing
                                )
                            }
                            .padding(
                                .vertical,
                                2
                            )
                        }
                    }
                }
            }
        }
    }

    private struct TaskLogEntry:
        Identifiable
    {
        let id: String
        let timestamp: Date
        let text: String
        let detail: String?
        let icon: String
        let timeZoneID: String?
    }

    private func taskLogEntries(
        for root: WorkItem
    ) -> [TaskLogEntry] {
        let ids: Set<UUID>

        if root.kind == .task {
            ids =
                Set(
                    descendantIDs(
                        of: root.id
                    )
                )
                .union(
                    [root.id]
                )
        } else {
            ids = [root.id]
        }

        let items =
            store.data.workItems
                .filter {
                    ids.contains(
                        $0.id
                    )
                }

        let itemByID =
            Dictionary(
                uniqueKeysWithValues:
                    items.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        let storedEvents =
            store.data.historyEvents
                .filter {
                    ids.contains(
                        $0.workItemID
                    )
                }

        var entries:
            [TaskLogEntry] = []

        for event in storedEvents {
            guard
                let work =
                    itemByID[
                        event.workItemID
                    ]
            else {
                continue
            }

            if
                work.kind
                    == .activity,
                event.kind
                    == .created
            {
                continue
            }

            if
                event.kind
                    == .statusChanged,
                (
                    event.newValue
                        == TaskStatus
                            .inProgress
                            .rawValue
                    ||
                    event.newValue
                        == TaskStatus
                            .completed
                            .rawValue
                )
            {
                continue
            }

            entries.append(
                TaskLogEntry(
                    id:
                        "history-\(event.id.uuidString)",
                    timestamp:
                        event.timestamp,
                    text:
                        historyText(
                            event,
                            work: work
                        ),
                    detail:
                        historyDetail(
                            event
                        ),
                    icon:
                        historyIcon(
                            event.kind
                        ),
                    timeZoneID:
                        event.timeZoneID
                )
            )
        }

        for work in items
        where work.kind == .task {
            let hasStartedEvent =
                storedEvents.contains {
                    $0.workItemID
                        == work.id
                    &&
                    $0.kind
                        == .started
                }

            if
                !hasStartedEvent,
                let startedAt =
                    work.startedAt
            {
                entries.append(
                    TaskLogEntry(
                        id:
                            "legacy-start-\(work.id.uuidString)",
                        timestamp:
                            startedAt,
                        text:
                            "\(logTitle(work)) started",
                        detail:
                            nil,
                        icon:
                            "play.circle",
                        timeZoneID:
                            work.startedTimeZoneID
                    )
                )
            }

            let hasCompletedEvent =
                storedEvents.contains {
                    $0.workItemID
                        == work.id
                    &&
                    $0.kind
                        == .completed
                }

            if
                !hasCompletedEvent,
                let completedAt =
                    work.completedAt
            {
                entries.append(
                    TaskLogEntry(
                        id:
                            "legacy-complete-\(work.id.uuidString)",
                        timestamp:
                            completedAt,
                        text:
                            "\(logTitle(work)) completed",
                        detail:
                            nil,
                        icon:
                            "checkmark.circle",
                        timeZoneID:
                            work.completedTimeZoneID
                    )
                )
            }
        }

        for work in items
        where work.kind == .activity {
            guard
                let occurred =
                    work.loggedAt
            else {
                continue
            }

            entries.append(
                TaskLogEntry(
                    id:
                        "event-\(work.id.uuidString)",
                    timestamp:
                        occurred,
                    text:
                        logTitle(
                            work
                        ),
                    detail:
                        work.body
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty
                        ? nil
                        : work.body,
                    icon:
                        "clock.arrow.circlepath",
                    timeZoneID:
                        work.loggedTimeZoneID
                )
            )
        }

        return entries
            .sorted {
                if
                    $0.timestamp
                        == $1.timestamp
                {
                    return
                        $0.id
                        > $1.id
                }

                return
                    $0.timestamp
                    > $1.timestamp
            }
    }

    private func historyText(
        _ event: HistoryEvent,
        work: WorkItem
    ) -> String {
        let title =
            logTitle(
                work
            )

        switch event.kind {
        case .created:
            switch work.kind {
            case .task:
                return
                    "\(title) created"

            case .note:
                return
                    "\(title) note added"

            case .activity:
                return title
            }

        case .edited:
            return
                event.text
                ?? "\(title) edited"

        case .statusChanged:
            if
                let raw =
                    event.newValue,
                let status =
                    TaskStatus(
                        rawValue: raw
                    )
            {
                return
                    "\(title) status changed to \(status.displayName)"
            }

            return
                event.text
                ?? "\(title) status changed"

        case .scheduled:
            return
                event.text
                ?? "\(title) scheduled"

        case .started:
            return
                event.text
                ?? "\(title) started"

        case .completed:
            return
                event.text
                ?? "\(title) completed"

        case .activityLogged:
            return
                event.text
                ?? title

        case .relationshipAdded:
            return
                event.text
                ?? "\(title) relationship added"

        case .relationshipRemoved:
            return
                event.text
                ?? "\(title) relationship removed"

        case .moved:
            return
                event.text
                ?? "\(title) moved"
        }
    }

    private func historyDetail(
        _ event: HistoryEvent
    ) -> String? {
        if
            event.kind == .scheduled,
            let newValue =
                event.newValue
        {
            if
                let date =
                    ISO8601DateFormatter()
                        .date(
                            from:
                                newValue
                        )
            {
                return
                    "Deadline: \(DReportTime.displayDateTime(date, sourceTimeZoneID: event.valueTimeZoneID))"
            }
        }

        return nil
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
            return "calendar.badge.clock"

        case .started:
            return "play.circle"

        case .completed:
            return "checkmark.circle"

        case .activityLogged:
            return "clock.arrow.circlepath"

        case .relationshipAdded:
            return "link.badge.plus"

        case .relationshipRemoved:
            return "link.badge.minus"

        case .moved:
            return "arrow.turn.down.right"
        }
    }

    private func logTitle(
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
            return body
        }

        switch item.kind {
        case .task:
            return "Task"

        case .note:
            return "Note"

        case .activity:
            return "Event"
        }
    }

    private var sortedThemes:
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

    private var sortedEntities:
        [Entity]
    {
        store.data.entities
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }

    private func availableParentTasks(
        for itemID: UUID
    ) -> [WorkItem] {
        let excluded =
            descendantIDs(
                of: itemID
            )
            .union([itemID])

        return store.data.workItems
            .filter {
                $0.kind == .task
                && !excluded.contains(
                    $0.id
                )
            }
            .sorted {
                displayTitle($0)
                    .localizedCaseInsensitiveCompare(
                        displayTitle($1)
                    )
                    == .orderedAscending
            }
    }

    private func descendantIDs(
        of itemID: UUID
    ) -> Set<UUID> {
        var result =
            Set<UUID>()

        var queue = [itemID]

        while let current =
            queue.first
        {
            queue.removeFirst()

            let children =
                store.data.workItems
                    .filter {
                        $0.parentWorkItemID
                            == current
                    }

            for child in children {
                if
                    result.insert(
                        child.id
                    ).inserted
                {
                    queue.append(
                        child.id
                    )
                }
            }
        }

        return result
    }

    private func beginTextEdit(
        _ field: EditableField,
        value: String
    ) {
        editingField = field
        textDraft = value
        errorMessage = nil
    }

    private func beginDateEdit(
        _ field: EditableField,
        date: Date?,
        timeZoneID: String?
    ) {
        editingField = field

        dateTimeZoneDraft =
            DReportTime
                .validTimeZoneIdentifier(
                    timeZoneID
                )
            ?? DReportTime
                .deviceTimeZoneID

        dateEnabledDraft =
            date != nil

        dateDraft =
            date
            ?? Calendar.autoupdatingCurrent.date(
                byAdding: .day,
                value: 1,
                to: Date()
            )
            ?? Date()

        errorMessage = nil
    }

    private func cancelEdit() {
        editingField = nil
        errorMessage = nil
    }

    private func saveTitle(
        _ item: WorkItem
    ) {
        finish(
            update(
                item,
                title:
                    textDraft
            )
        )
    }

    private func saveBody(
        _ item: WorkItem
    ) {
        finish(
            update(
                item,
                body:
                    textDraft
            )
        )
    }

    private func saveTheme(
        _ item: WorkItem
    ) {
        finish(
            update(
                item,
                themeID:
                    uuidDraft,
                themeWasEdited:
                    true
            )
        )
    }


    private func saveParent(
        _ item: WorkItem
    ) {
        finish(
            update(
                item,
                parentID:
                    uuidDraft,
                parentWasEdited:
                    true
            )
        )
    }

    private func saveStatus(
        _ item: WorkItem
    ) {
        finish(
            update(
                item,
                status:
                    statusDraft
            )
        )
    }

    private func saveDate(
        _ field: EditableField,
        item: WorkItem
    ) {
        let value =
            dateEnabledDraft
            ? dateDraft
            : nil

        switch field {
        case .deadline:
            finish(
                update(
                    item,
                    deadline:
                        value,
                    deadlineTimeZoneID:
                        dateEnabledDraft
                        ? dateTimeZoneDraft
                        : nil,
                    deadlineWasEdited:
                        true
                )
            )

        case .reminder:
            finish(
                update(
                    item,
                    reminder:
                        value,
                    reminderTimeZoneID:
                        dateEnabledDraft
                        ? dateTimeZoneDraft
                        : nil,
                    reminderWasEdited:
                        true
                )
            )

        case .eventDate:
            finish(
                update(
                    item,
                    loggedAt:
                        value,
                    loggedTimeZoneID:
                        dateEnabledDraft
                        ? dateTimeZoneDraft
                        : nil,
                    loggedAtWasEdited:
                        true
                )
            )

        default:
            break
        }
    }

    private func saveRelationship(
        _ relationship:
            WorkEntityRelationship
    ) {
        guard
            let relationshipEntityDraft
        else {
            errorMessage =
                "Select a related entity."
            return
        }

        let error =
            store
                .updateWorkRelationshipDetails(
                    relationshipID:
                        relationship.id,
                    entityID:
                        relationshipEntityDraft,
                    role:
                        relationshipRoleDraft
                )

        finish(error)
    }

    private func finish(
        _ error: String?
    ) {
        if let error {
            errorMessage = error
        } else {
            editingField = nil
            errorMessage = nil
        }
    }

    private func update(
        _ item: WorkItem,
        title: String? = nil,
        body: String? = nil,
        themeID: UUID? = nil,
        themeWasEdited: Bool = false,
        parentID: UUID? = nil,
        parentWasEdited: Bool = false,
        status: TaskStatus? = nil,
        deadline: Date? = nil,
        deadlineTimeZoneID: String? = nil,
        deadlineWasEdited: Bool = false,
        reminder: Date? = nil,
        reminderTimeZoneID: String? = nil,
        reminderWasEdited: Bool = false,
        loggedAt: Date? = nil,
        loggedTimeZoneID: String? = nil,
        loggedAtWasEdited: Bool = false
    ) -> String? {
        store.updateWorkItemDetails(
            itemID:
                item.id,
            title:
                title
                ?? item.title
                ?? "",
            body:
                body
                ?? item.body,
            themeID:
                themeWasEdited
                ? themeID
                : item.themeID,
            parentWorkItemID:
                parentWasEdited
                ? parentID
                : item.parentWorkItemID,
            status:
                item.kind == .task
                ? (
                    status
                    ?? item.status
                    ?? .todo
                )
                : nil,
            deadlineAt:
                item.kind == .task
                ? (
                    deadlineWasEdited
                    ? deadline
                    : item.deadlineAt
                )
                : nil,
            reminderAt:
                item.kind != .task
                ? (
                    reminderWasEdited
                    ? reminder
                    : item.reminderAt
                )
                : nil,
            scheduledAt:
                nil,
            loggedAt:
                item.kind == .activity
                ? (
                    loggedAtWasEdited
                    ? loggedAt
                    : item.loggedAt
                )
                : item.loggedAt,
            deadlineTimeZoneID:
                deadlineWasEdited
                ? deadlineTimeZoneID
                : item.deadlineTimeZoneID,
            reminderTimeZoneID:
                reminderWasEdited
                ? reminderTimeZoneID
                : item.reminderTimeZoneID,
            loggedTimeZoneID:
                loggedAtWasEdited
                ? loggedTimeZoneID
                : item.loggedTimeZoneID
        )
    }

    private func parentName(
        _ item: WorkItem
    ) -> String {
        guard
            let parentID =
                item.parentWorkItemID,
            let parent =
                store.workItem(
                    id: parentID
                )
        else {
            return "None"
        }

        return displayTitle(
            parent
        )
    }

    private func childItems(
        of parentID: UUID
    ) -> [WorkItem] {
        store.data.workItems
            .filter {
                $0.parentWorkItemID
                    == parentID
            }
            .sorted {
                $0.createdAt
                    < $1.createdAt
            }
    }

    private func hierarchyPath(
        for item: WorkItem
    ) -> [String] {
        var path = [
            displayTitle(item)
        ]

        var parentID =
            item.parentWorkItemID

        var visited =
            Set<UUID>()

        while
            let currentID =
                parentID,
            !visited.contains(
                currentID
            ),
            let parent =
                store.workItem(
                    id: currentID
                )
        {
            visited.insert(
                currentID
            )

            path.insert(
                displayTitle(parent),
                at: 0
            )

            parentID =
                parent.parentWorkItemID
        }

        return path
    }

    private func displayTitle(
        _ item: WorkItem
    ) -> String {
        if
            let title = item.title,
            !title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        {
            return title
        }

        if !item.body.isEmpty {
            return item.body
        }

        return typeLabel(item)
    }

    private func typeLabel(
        _ item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            return "Task"

        case .note:
            return "Note"

        case .activity:
            return "Event"
        }
    }

    private func largeIcon(
        _ item: WorkItem
    ) -> String {
        switch item.kind {
        case .task:
            switch item.status {
            case .completed:
                return "checkmark.circle"

            case .inProgress:
                return "clock"

            case .todo,
                 nil:
                return "circle"
            }

        case .note:
            if item.reminderAt != nil {
                return "bell"
            }

            return "note.text"

        case .activity:
            return "calendar"
        }
    }

    private func formatted(
        _ date: Date
    ) -> String {
        DReportTime.dateTime(
            date,
            includeTimeZone:
                true
        )
    }


    private func relationshipLabel(
        _ role:
            WorkRelationshipRole
    ) -> String {
        switch role {
        case .forWhom:
            return "For"

        case .requestedBy:
            return "Requested by"

        case .with:
            return "With"

        case .assignedTo:
            return "Assigned to"

        case .relatedTo:
            return "Related to"
        }
    }
}

private struct InspectorSection<
    Content: View
>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content:
            () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(title)
                .font(.headline)

            content
        }
    }
}

private struct EditableValueRow:
    View
{
    let label: String
    let value: String
    let onEdit: () -> Void

    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing: 16
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 110,
                    alignment: .leading
                )

            Text(value)
                .textSelection(
                    .enabled
                )

            Spacer()

            InlineEditButton(
                action: onEdit
            )
        }
        .font(.callout)
    }
}

private struct ReadOnlyInspectorRow:
    View
{
    let label: String
    let value: String

    var body: some View {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing: 16
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 110,
                    alignment: .leading
                )

            Text(value)
                .textSelection(
                    .enabled
                )

            Spacer()
        }
        .font(.callout)
    }
}

private struct InlineEditorRow<
    Content: View
>: View {
    let label: String
    let content: Content

    init(
        label: String,
        @ViewBuilder content:
            () -> Content
    ) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 110,
                    alignment: .leading
                )

            content
        }
        .font(.callout)
    }
}

private struct InlineEditButton:
    View
{
    let action: () -> Void

    var body: some View {
        Button(
            action: action
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
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .help("Edit")
    }
}

private struct InlineEditActions:
    View
{
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(
                .borderless
            )

            Button("Save") {
                onSave()
            }
            .buttonStyle(
                .borderless
            )
            .fontWeight(
                .medium
            )
        }
        .font(.caption)
    }
}


private struct DetailValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
        ) {
            Text(label)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 100,
                    alignment: .leading
                )

            Text(value)
                .textSelection(
                    .enabled
                )

            Spacer()
        }
        .font(.callout)
    }
}


struct ThemeDetailView: View {
    @EnvironmentObject
    private var store: DReportStore

    let themeID: UUID

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft =
        ""

    @State
    private var parentDraft:
        UUID?

    @State
    private var errorMessage:
        String?

    private enum EditableField:
        Hashable
    {
        case name
        case notes
        case parent
    }

    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let theme =
                    store.theme(
                        id: themeID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        header(theme)

                        InspectorSection(
                            title: "Details"
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 10
                            ) {
                                parentRow(theme)

                                notesRow(theme)
                            }
                        }

                        InspectorSection(
                            title: "History"
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 9
                            ) {
                                ReadOnlyInspectorRow(
                                    label: "Created",
                                    value:
                                        DReportTime
                                            .dateTime(
                                                theme.createdAt
                                            )
                                )

                                ReadOnlyInspectorRow(
                                    label: "Updated",
                                    value:
                                        DReportTime
                                            .dateTime(
                                                theme.updatedAt
                                            )
                                )
                            }
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
            } else {
                ContentUnavailableView(
                    "Theme Not Found",
                    systemImage:
                        "folder.badge.questionmark"
                )
            }
        }
    }

    private func header(
        _ theme: Theme
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    "folder"
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                if
                    editingField
                        == .name
                {
                    TextField(
                        "Theme name",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    InlineEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveName(
                                theme
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(
                            theme.name
                        )
                        .font(.title2)
                        .fontWeight(
                            .semibold
                        )

                        InlineEditButton {
                            textDraft =
                                theme.name

                            editingField =
                                .name
                        }
                    }
                }

                Text("Theme")
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func parentRow(
        _ theme: Theme
    ) -> some View {
        if
            editingField
                == .parent
        {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                HStack {
                    Text("Parent")
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            width: 100,
                            alignment: .leading
                        )

                    Picker(
                        "",
                        selection:
                            $parentDraft
                    ) {
                        Text("None")
                            .tag(
                                Optional<UUID>
                                    .none
                            )

                        ForEach(
                            availableParents(
                                theme
                            )
                        ) { candidate in
                            Text(
                                candidate.name
                            )
                            .tag(
                                Optional(
                                    candidate.id
                                )
                            )
                        }
                    }
                    .labelsHidden()

                    Spacer()
                }

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveParent(
                            theme
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Parent",
                value:
                    store.theme(
                        id:
                            theme
                                .parentThemeID
                    )?.name
                    ?? "None",
                onEdit: {
                    parentDraft =
                        theme
                            .parentThemeID

                    editingField =
                        .parent
                }
            )
        }
    }

    @ViewBuilder
    private func notesRow(
        _ theme: Theme
    ) -> some View {
        if
            editingField
                == .notes
        {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

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

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveNotes(
                            theme
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Notes",
                value:
                    theme.notes
                        .isEmpty
                    ? "None"
                    : theme.notes,
                onEdit: {
                    textDraft =
                        theme.notes

                    editingField =
                        .notes
                }
            )
        }
    }

    private func availableParents(
        _ theme: Theme
    ) -> [Theme] {
        let descendants =
            Set(
                store
                    .themeDescendantIDs(
                        of: theme.id
                    )
            )

        return store.data.themes
            .filter {
                $0.id != theme.id
                && !descendants
                    .contains(
                        $0.id
                    )
            }
            .sorted {
                $0.name
                    .localizedCaseInsensitiveCompare(
                        $1.name
                    )
                    == .orderedAscending
            }
    }

    private func saveName(
        _ theme: Theme
    ) {
        finish(
            store
                .updateThemeDetails(
                    themeID:
                        theme.id,
                    name:
                        textDraft,
                    parentThemeID:
                        theme
                            .parentThemeID,
                    notes:
                        theme.notes
                )
        )
    }

    private func saveParent(
        _ theme: Theme
    ) {
        finish(
            store
                .updateThemeDetails(
                    themeID:
                        theme.id,
                    name:
                        theme.name,
                    parentThemeID:
                        parentDraft,
                    notes:
                        theme.notes
                )
        )
    }

    private func saveNotes(
        _ theme: Theme
    ) {
        finish(
            store
                .updateThemeDetails(
                    themeID:
                        theme.id,
                    name:
                        theme.name,
                    parentThemeID:
                        theme
                            .parentThemeID,
                    notes:
                        textDraft
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
}


struct StructureEntityDetailView:
    View
{
    @EnvironmentObject
    private var store: DReportStore

    let entityID: UUID

    @State
    private var editingField:
        EditableField?

    @State
    private var textDraft =
        ""

    @State
    private var containerIDsDraft:
        Set<UUID> = []

    @State
    private var errorMessage:
        String?

    private enum EditableField:
        Hashable
    {
        case name
        case notes
        case memberships
    }

    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            if
                let entity =
                    store.entity(
                        id: entityID
                    )
            {
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        header(entity)

                        InspectorSection(
                            title: "Details"
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 10
                            ) {
                                ReadOnlyInspectorRow(
                                    label: "Type",
                                    value:
                                        entity
                                            .kind
                                            .displayName
                                )

                                notesRow(
                                    entity
                                )
                            }
                        }

                        membershipsSection(
                            entity
                        )

                        InspectorSection(
                            title: "History"
                        ) {
                            VStack(
                                alignment: .leading,
                                spacing: 9
                            ) {
                                ReadOnlyInspectorRow(
                                    label: "Created",
                                    value:
                                        DReportTime
                                            .dateTime(
                                                entity
                                                    .createdAt
                                            )
                                )

                                ReadOnlyInspectorRow(
                                    label: "Updated",
                                    value:
                                        DReportTime
                                            .dateTime(
                                                entity
                                                    .updatedAt
                                            )
                                )
                            }
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
            } else {
                ContentUnavailableView(
                    "Item Not Found",
                    systemImage:
                        "questionmark.circle"
                )
            }
        }
    }

    private func header(
        _ entity: Entity
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            Image(
                systemName:
                    entityIcon(
                        entity
                    )
            )
            .font(.title2)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                if
                    editingField
                        == .name
                {
                    TextField(
                        "Name",
                        text:
                            $textDraft
                    )
                    .font(.title2)

                    InlineEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveName(
                                entity
                            )
                        }
                    )
                } else {
                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 8
                    ) {
                        Text(
                            entity.name
                        )
                        .font(.title2)
                        .fontWeight(
                            .semibold
                        )

                        InlineEditButton {
                            textDraft =
                                entity.name

                            editingField =
                                .name
                        }
                    }
                }

                Text(
                    entity
                        .kind
                        .displayName
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func notesRow(
        _ entity: Entity
    ) -> some View {
        if
            editingField
                == .notes
        {
            VStack(
                alignment: .leading,
                spacing: 7
            ) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

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

                InlineEditActions(
                    onCancel:
                        cancelEdit,
                    onSave: {
                        saveNotes(
                            entity
                        )
                    }
                )
            }
        } else {
            EditableValueRow(
                label: "Notes",
                value:
                    entity.notes
                        .isEmpty
                    ? "None"
                    : entity.notes,
                onEdit: {
                    textDraft =
                        entity.notes

                    editingField =
                        .notes
                }
            )
        }
    }

    private func membershipsSection(
        _ entity: Entity
    ) -> some View {
        let current =
            store.containers(
                for: entity.id
            )

        return InspectorSection(
            title: "Structure"
        ) {
            if
                editingField
                    == .memberships
            {
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    if
                        availableContainers(
                            entity
                        )
                        .isEmpty
                    {
                        Text(
                            "No compatible containers."
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                    } else {
                        ForEach(
                            availableContainers(
                                entity
                            )
                        ) { candidate in
                            Toggle(
                                candidate.name,
                                isOn:
                                    membershipBinding(
                                        candidate.id
                                    )
                            )
                            .toggleStyle(
                                .checkbox
                            )
                        }
                    }

                    InlineEditActions(
                        onCancel:
                            cancelEdit,
                        onSave: {
                            saveMemberships(
                                entity
                            )
                        }
                    )
                }
            } else {
                EditableValueRow(
                    label:
                        membershipLabel(
                            entity
                        ),
                    value:
                        current.isEmpty
                        ? "Independent"
                        : current
                            .map(
                                \.name
                            )
                            .joined(
                                separator: " · "
                            ),
                    onEdit: {
                        containerIDsDraft =
                            Set(
                                current.map(
                                    \.id
                                )
                            )

                        editingField =
                            .memberships
                    }
                )
            }
        }
    }

    private func availableContainers(
        _ entity: Entity
    ) -> [Entity] {
        let descendants =
            Set(
                store
                    .entityDescendantIDs(
                        of: entity.id
                    )
            )

        return store
            .possibleContainers(
                for: entity.kind
            )
            .filter {
                $0.id
                    != entity.id
                && !descendants
                    .contains(
                        $0.id
                    )
            }
    }

    private func membershipBinding(
        _ id: UUID
    ) -> Binding<Bool> {
        Binding(
            get: {
                containerIDsDraft
                    .contains(id)
            },
            set: {
                enabled in

                if enabled {
                    containerIDsDraft
                        .insert(id)
                } else {
                    containerIDsDraft
                        .remove(id)
                }
            }
        )
    }

    private func saveName(
        _ entity: Entity
    ) {
        finish(
            store
                .updateEntityDetails(
                    entityID:
                        entity.id,
                    name:
                        textDraft,
                    notes:
                        entity.notes
                )
        )
    }

    private func saveNotes(
        _ entity: Entity
    ) {
        finish(
            store
                .updateEntityDetails(
                    entityID:
                        entity.id,
                    name:
                        entity.name,
                    notes:
                        textDraft
                )
        )
    }

    private func saveMemberships(
        _ entity: Entity
    ) {
        finish(
            store
                .updateEntityMemberships(
                    entityID:
                        entity.id,
                    containerIDs:
                        containerIDsDraft
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

    private func entityIcon(
        _ entity: Entity
    ) -> String {
        switch entity.kind {
        case .organization:
            return "building.2"

        case .group:
            return "person.3"

        case .person:
            return "person.crop.circle"
        }
    }

    private func membershipLabel(
        _ entity: Entity
    ) -> String {
        switch entity.kind {
        case .organization:
            return "Parent"

        case .group:
            return "Containers"

        case .person:
            return "Affiliations"
        }
    }
}


struct WorkDetailRouterView: View {

    @EnvironmentObject
    private var store: DReportStore

    let section: SidebarSection

    @Binding
    var selectedThemeID: UUID?

    @Binding
    var selectedOrganizationID: UUID?

    @Binding
    var selectedGroupID: UUID?

    @Binding
    var selectedWorkItemID: UUID?

    @Binding
    var selectedCalendarEventID: UUID?

    @Binding
    var selectedPersonID: UUID?

    @Binding
    var calendarEventCreationRequest:
        CalendarEventCreationRequest?

    @Binding
    var workCreationRequest:
        WorkCreationRequest?


    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            Group {
                if
                    section == .calendar,
                    let request =
                        calendarEventCreationRequest
                {
                    CalendarEventCreationView(
                        request:
                            request,
                        creationRequest:
                            $calendarEventCreationRequest,
                        selectedCalendarEventID:
                            $selectedCalendarEventID
                    )
                    .id(request.id)

                } else if
                    section == .calendar,
                    let selectedCalendarEventID
                {
                    CalendarEventDetailView(
                        eventID:
                            selectedCalendarEventID
                    )

                } else if
                    let request =
                        workCreationRequest
                {
                    WorkEntryCreationView(
                        request:
                            request,
                        workCreationRequest:
                            $workCreationRequest,
                        selectedWorkItemID:
                            $selectedWorkItemID
                    )
                    .id(request.id)

                } else if
                    section == .themes,
                    let selectedWorkItemID
                {
                    WorkItemDetailView(
                        itemID:
                            selectedWorkItemID,
                        selectedWorkItemID:
                            $selectedWorkItemID
                    )

                } else if
                    section == .themes,
                    let selectedThemeID
                {
                    RichThemeDetailView(
                        themeID:
                            selectedThemeID
                    )
                } else if
                    section
                        == .organizations,
                    let selectedOrganizationID
                {
                    RichStructureEntityDetailView(
                        entityID:
                            selectedOrganizationID
                    )
                } else if
                    section
                        == .groups,
                    let selectedGroupID
                {
                    RichStructureEntityDetailView(
                        entityID:
                            selectedGroupID
                    )
                } else if
                    section == .people,
                    let selectedPersonID
                {
                    PersonDetailView(
                        personID:
                            selectedPersonID
                    )
                } else if
                    isWorkSection,
                    let selectedWorkItemID
                {
                    WorkItemDetailView(
                        itemID:
                            selectedWorkItemID,
                        selectedWorkItemID:
                            $selectedWorkItemID
                    )
                } else {
                    DetailPlaceholderView()
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            DReportStyle
                .contentBackground
        )
    
        .safeAreaInset(
            edge:
                .bottom,
            spacing:
                0
        ) {
            deleteFooter
        }
}

    private var isWorkSection: Bool {
        switch section {
        case .today,
             .calendar,
             .allTasks,
             .todo,
             .inProgress,
             .completed,
             .timeline:
            return true

        default:
            return false
        }
    }


    @ViewBuilder
    private var deleteFooter:
        some View
    {
        if
            workCreationRequest
                == nil
        {
            if
                section == .calendar,
                let id =
                    selectedCalendarEventID,
                let event =
                    store.calendarEvent(
                        id: id
                    ),
                !store
                    .isReadOnlyCalendarEvent(
                        event
                    )
            {
                ProtectedDeleteButton(
                    objectType:
                        "Calendar Event",
                    objectName:
                        event.title,
                    warning:
                        "This permanently deletes this Calendar Event from DReport. If it belongs to a synchronized external calendar, the deletion will be queued for synchronization.",
                    deleteAction: {
                        store.deleteCalendarEvent(
                            id: id
                        )

                        return nil
                    },
                    onDeleted: {
                        selectedCalendarEventID =
                            nil
                    }
                )

            } else if
                section == .themes,
                let id =
                    selectedWorkItemID,
                let item =
                    store.workItem(
                        id:
                            id
                    )
            {
                protectedWorkDelete(
                    item
                )

            } else if
                section == .themes,
                let id =
                    selectedThemeID,
                let theme =
                    store.theme(
                        id:
                            id
                    )
            {
                ProtectedDeleteButton(
                    objectType:
                        "Theme",
                    objectName:
                        theme.name,
                    warning:
                        "This permanently deletes this Theme, all of its descendant Themes, and every Work entry assigned anywhere inside that Theme hierarchy.",
                    deleteAction: {
                        store.deleteTheme(
                            id:
                                id
                        )

                        return nil
                    },
                    onDeleted: {
                        selectedThemeID =
                            nil

                        selectedWorkItemID =
                            nil
                    }
                )

            } else if
                section
                    == .organizations,
                let id =
                    selectedOrganizationID,
                let entity =
                    store.entity(
                        id:
                            id
                    )
            {
                protectedEntityDelete(
                    entity
                ) {
                    selectedOrganizationID =
                        nil
                }

            } else if
                section
                    == .groups,
                let id =
                    selectedGroupID,
                let entity =
                    store.entity(
                        id:
                            id
                    )
            {
                protectedEntityDelete(
                    entity
                ) {
                    selectedGroupID =
                        nil
                }

            } else if
                section
                    == .people,
                let id =
                    selectedPersonID,
                let entity =
                    store.entity(
                        id:
                            id
                    )
            {
                protectedEntityDelete(
                    entity
                ) {
                    selectedPersonID =
                        nil
                }

            } else if
                deleteWorkSection,
                let id =
                    selectedWorkItemID,
                let item =
                    store.workItem(
                        id:
                            id
                    )
            {
                protectedWorkDelete(
                    item
                )
            }
        }
    }


    private func protectedWorkDelete(
        _ item: WorkItem
    ) -> some View {
        ProtectedDeleteButton(
            objectType:
                item.kind
                    .displayName,
            objectName:
                deletionName(
                    item
                ),
            warning:
                "This permanently deletes this \(item.kind.displayName) and every child item beneath it. Relationships and history belonging to those deleted items are also removed.",
            deleteAction: {
                store.deleteWorkItem(
                    id:
                        item.id
                )

                return nil
            },
            onDeleted: {
                selectedWorkItemID =
                    nil
            }
        )
    }


    private func protectedEntityDelete(
        _ entity: Entity,
        onDeleted:
            @escaping () -> Void
    ) -> some View {
        ProtectedDeleteButton(
            objectType:
                entity.kind
                    .displayName,
            objectName:
                entity.name,
            warning:
                entityDeleteWarning(
                    entity
                ),
            deleteAction: {
                store
                    .deleteEntityProtected(
                        id:
                            entity.id
                    )
            },
            onDeleted:
                onDeleted
        )
    }


    private func entityDeleteWarning(
        _ entity: Entity
    ) -> String {
        if
            entity.kind
                == .person,
            let user =
                store.user(
                    linkedToPerson:
                        entity.id
                )
        {
            return
                "This Person is linked to the DReport account @\(user.username). The account must be unlinked or removed before this Person can be deleted."
        }

        switch entity.kind {
        case .organization:
            return
                "This permanently deletes this Organization and removes its structural memberships and Work relationships. Entities that belonged to it are kept."

        case .group:
            return
                "This permanently deletes this Group and removes its structural memberships and Work relationships. People and other entities inside it are kept."

        case .person:
            return
                "This permanently deletes this Person, their Person profile, structural memberships and Work relationships."
        }
    }


    private func deletionName(
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
                body.prefix(80)
            )
        }

        return
            item.kind
                .displayName
    }


    private var deleteWorkSection:
        Bool
    {
        switch section {
        case .today,
             .calendar,
             .allTasks,
             .todo,
             .inProgress,
             .completed,
             .timeline:

            return true

        default:
            return false
        }
    }
}
