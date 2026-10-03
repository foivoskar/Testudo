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
    private var store: TestudoStore

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
                List {
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
            TestudoStyle.contentBackground
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
                    .middleColumnSelectionStyle(
                        selection == item.id,
                        leadingExtension:
                            4,
                        trailingExtension:
                            4
                    )
                    .contentShape(
                        Rectangle()
                    )
                    .onTapGesture {
                        selection =
                            item.id
                    }
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
            .sorted { priorityDateSort($0, $1) }
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
            .sorted { priorityDateSort($0, $1) }
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
            .sorted { priorityDateSort($0, $1) }
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
                "Reminder \(TestudoTime.displayTime(reminder, sourceTimeZoneID: item.reminderTimeZoneID))"
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
    private var store: TestudoStore

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
                List {
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
                        .middleColumnSelectionStyle(
                            selection
                                == entry.item.id,
                            leadingExtension:
                                4,
                            trailingExtension:
                                4
                        )
                        .contentShape(
                            Rectangle()
                        )
                        .onTapGesture {
                            selection =
                                entry.item.id
                        }
                    }
                }
                .listStyle(.inset)

            } else {
                List {
                    ForEach(items) { item in
                        WorkGuideRow(
                            item: item,
                            context:
                                genericContext(
                                    item
                                )
                        )
                        .middleColumnSelectionStyle(
                            selection == item.id,
                            leadingExtension:
                                4,
                            trailingExtension:
                                4
                        )
                        .contentShape(
                            Rectangle()
                        )
                        .onTapGesture {
                            selection =
                                item.id
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(
            TestudoStyle.contentBackground
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
                "Reminder \(TestudoTime.displayDateTime(reminder, sourceTimeZoneID: item.reminderTimeZoneID))"
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
    private var store: TestudoStore

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
                item.kind == .task
                ? AnyShapeStyle(
                    (
                        item.status
                        ?? .todo
                    )
                        .testudoStatusIconColor
                )
                : AnyShapeStyle(
                    iconStyle
                )
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
            return "Activity"
        }
    }

    private var icon: String {
        switch item.kind {
        case .task:
            switch item.status {
            case .completed:
                return "checkmark.circle"

            case .closed:
                return "archivebox"
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
            return "waveform.path.ecg"
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
    private var store: TestudoStore

    let itemID: UUID

    @Binding
    var selectedWorkItemID:
        UUID?

    private let detailDeleteFooter:
        AnyView


    init<DeleteFooter: View>(
        itemID: UUID,
        selectedWorkItemID:
            Binding<UUID?>,
        @ViewBuilder
        deleteFooter:
            () -> DeleteFooter
    ) {
        self.itemID =
            itemID

        self._selectedWorkItemID =
            selectedWorkItemID

        self.detailDeleteFooter =
            AnyView(
                deleteFooter()
            )
    }

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
        TestudoTime.deviceTimeZoneID

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
        TestudoTime.deviceTimeZoneID

    @State
    private var childHasReminder =
        false

    @State
    private var childReminderDraft =
        Date()

    @State
    private var childReminderTimeZoneID =
        TestudoTime.deviceTimeZoneID

    @State
    private var childHasOccurredAt =
        false

    @State
    private var childOccurredAtDraft =
        Date()

    @State
    private var childOccurredTimeZoneID =
        TestudoTime.deviceTimeZoneID

    @State
    private var childErrorMessage:
        String?

    @State
    private var errorMessage:
        String?


    @State
    private var showingParentRelationshipChoice =
        false

    @State
    private var pendingParentRelationshipSourceID:
        UUID?

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
        case activityDate
        case relationship(UUID)
    }

    var body: some View {
        ZStack {
            TestudoStyle
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
                        spacing: 22
                    ) {
                        header(item)

                        taskDetailDivider

                        descriptionSection(
                            item
                        )

                        taskDetailDivider

                        detailsSection(
                            item
                        )

                        hierarchySection(
                            item
                        )

                        taskDetailDivider

                        childrenSection(
                            item
                        )

                        taskDetailDivider

                        relationshipsSection(
                            item
                        )

                        taskDetailDivider

                        historySection(
                            item
                        )

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
                    TestudoStyle
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
            TestudoStyle
                .contentBackground
        )
        .confirmationDialog(
            "Use Parent Relationships?",
            isPresented:
                $showingParentRelationshipChoice,
            titleVisibility:
                .visible
        ) {
            Button(
                "Copy Parent Relationships"
            ) {
                copyPendingParentRelationships()
            }

            Button(
                "Keep Current Relationships",
                role:
                    .cancel
            ) {
                pendingParentRelationshipSourceID =
                    nil
            }

        } message: {
            Text(
                "The Parent Task has been saved. Copying will replace this Task's current Related People, Groups & Organizations with the Parent's relationships marked “Inherited by child items”. The copied relationships can be edited normally afterward."
            )
        }
    }

    private var taskDetailDivider:
        some View
    {
        Divider()
            .opacity(
                0.55
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
            .testudoTaskStatusSymbolColor(
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

                        TestudoDestinationLink(
                            title:
                                theme.name,
                            destination:
                                .theme(
                                    theme.id
                                ),
                            color:
                                .secondary
                        )
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
                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    TextEditor(
                        text:
                            $textDraft
                    )
                    .font(.body)
                    .scrollContentBackground(
                        .hidden
                    )
                    .padding(
                        .horizontal,
                        10
                    )
                    .padding(
                        .vertical,
                        8
                    )
                    .frame(
                        minHeight: 96,
                        idealHeight: 110,
                        maxHeight: 140
                    )
                    .background(
                        Color(
                            nsColor:
                                .textBackgroundColor
                        ),
                        in:
                            RoundedRectangle(
                                cornerRadius: 10,
                                style:
                                    .continuous
                            )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 10,
                            style:
                                .continuous
                        )
                        .stroke(
                            Color.primary
                                .opacity(0.12),
                            lineWidth: 1
                        )
                    }

                    HStack(
                        spacing: 10
                    ) {
                        Spacer()

                        Button(
                            "Cancel"
                        ) {
                            cancelEdit()
                        }
                        .keyboardShortcut(
                            .cancelAction
                        )

                        Button(
                            "Save"
                        ) {
                            saveBody(
                                item
                            )
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .keyboardShortcut(
                            .defaultAction
                        )
                    }
                }
                .padding(
                    .top,
                    2
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
                            TestudoDestinationLink(
                                title:
                                    item.body,
                                destination:
                                    .work(
                                        item.id
                                    ),
                                color:
                                    .primary
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
        let current =
            store.workThemes(
                for:
                    item.id
            )

        HierarchicalSelectionSummaryRow(
            label:
                "Theme",
            selectedTitles:
                current.map(\.name),
            selectedDestinations:
                current.map {
                    .theme(
                        $0.id
                    )
                },
            selectorTitle:
                "Themes",
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
                "pencil",
            onSave: {
                selection in

                store.setWorkThemes(
                    workItemID:
                        item.id,
                    themeIDs:
                        selection
                )
            }
        )
    }

    @ViewBuilder
    private func parentRow(
        _ item: WorkItem
    ) -> some View {
        let currentParent =
            item.parentWorkItemID
                .flatMap {
                    store.workItem(
                        id:
                            $0
                    )
                }

        let excluded =
            descendantIDs(
                of:
                    item.id
            )
            .union(
                [item.id]
            )

        HierarchicalSelectionSummaryRow(
            label:
                "Parent",
            selectedTitles:
                currentParent
                    .map {
                        [
                            displayTitle(
                                $0
                            )
                        ]
                    }
                ?? [],
            selectedDestinations:
                currentParent
                    .map {
                        [
                            TestudoDetailDestination
                                .work(
                                    $0.id
                                )
                        ]
                    }
                ?? [],
            selectorTitle:
                "Parent Task",
            selectorMessage:
                "Tasks are shown in their real hierarchy. A work item can have only one Parent Task.",
            nodes:
                HierarchySelectionData
                    .taskNodes(
                        store:
                            store,
                        excludingWorkItemIDs:
                            excluded
                    ),
            initialSelection:
                Set(
                    currentParent
                        .map {
                            [$0.id]
                        }
                    ?? []
                ),
            buttonSystemImage:
                "pencil",
            maximumSelectionCount:
                1,
            onSave: {
                selection in

                let newParentID =
                    selection.first

                let previousParentID =
                    item.parentWorkItemID


                let error =
                    update(
                        item,
                        parentID:
                            newParentID,
                        parentWasEdited:
                            true
                    )


                if let error {
                    errorMessage =
                        error

                    return error
                }


                errorMessage =
                    nil


                // Only an existing Task that has just been
                // attached/re-attached to a Parent needs the
                // user's post-save relationship decision.
                if
                    item.kind == .task,
                    let newParentID,
                    newParentID
                        != previousParentID
                {
                    pendingParentRelationshipSourceID =
                        newParentID

                    showingParentRelationshipChoice =
                        true
                }


                return nil
            }
        )
    }

    @ViewBuilder
    private func statusRow(
        _ item: WorkItem
    ) -> some View {
        TaskStatusSelectorRow(
            status:
                item.status
                ?? .todo,
            allowsClosed:
                item.parentWorkItemID
                    == nil,
            onSave: {
                selectedStatus in

                update(
                    item,
                    status:
                        selectedStatus
                )
            }
        )
    }

    @ViewBuilder
    private func deadlineRow(
        _ item: WorkItem
    ) -> some View {
        DateTimeSelectorRow(
            label:
                "Deadline",
            value:
                item.deadlineAt,
            valueText:
                item.deadlineAt
                    .map {
                        TestudoTime
                            .displayDateTime(
                                $0,
                                sourceTimeZoneID:
                                    item
                                        .deadlineTimeZoneID
                            )
                    }
                ?? "None",
            timeZoneID:
                item.deadlineTimeZoneID,
            allowsEmpty:
                true,
            selectorTitle:
                "Deadline",
            selectorMessage:
                "Choose the deadline date, time and source time zone.",
            onSave: {
                date,
                timeZoneID in

                update(
                    item,
                    deadline:
                        date,
                    deadlineTimeZoneID:
                        timeZoneID,
                    deadlineWasEdited:
                        true
                )
            }
        )
    }

    @ViewBuilder
    private func reminderRow(
        _ item: WorkItem
    ) -> some View {
        DateTimeSelectorRow(
            label:
                "Reminder",
            value:
                item.reminderAt,
            valueText:
                item.reminderAt
                    .map {
                        TestudoTime
                            .displayDateTime(
                                $0,
                                sourceTimeZoneID:
                                    item
                                        .reminderTimeZoneID
                            )
                    }
                ?? "None",
            timeZoneID:
                item.reminderTimeZoneID,
            allowsEmpty:
                true,
            selectorTitle:
                "Reminder",
            selectorMessage:
                "Choose the reminder date, time and source time zone.",
            onSave: {
                date,
                timeZoneID in

                update(
                    item,
                    reminder:
                        date,
                    reminderTimeZoneID:
                        timeZoneID,
                    reminderWasEdited:
                        true
                )
            }
        )
    }

    @ViewBuilder
    private func occurredRow(
        _ item: WorkItem
    ) -> some View {
        DateTimeSelectorRow(
            label:
                "Occurred",
            value:
                item.loggedAt,
            valueText:
                item.loggedAt
                    .map {
                        TestudoTime
                            .displayDateTime(
                                $0,
                                sourceTimeZoneID:
                                    item
                                        .loggedTimeZoneID
                            )
                    }
                ?? "Unknown",
            timeZoneID:
                item.loggedTimeZoneID,
            allowsEmpty:
                false,
            selectorTitle:
                "Occurred",
            selectorMessage:
                "Choose when this Event occurred and the source time zone.",
            onSave: {
                date,
                timeZoneID in

                update(
                    item,
                    loggedAt:
                        date,
                    loggedTimeZoneID:
                        timeZoneID,
                    loggedAtWasEdited:
                        true
                )
            }
        )
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
                for:
                    item
            )

        if path.count > 1 {
            InspectorSection(
                title:
                    "Location"
            ) {
                ScrollView(
                    .horizontal,
                    showsIndicators:
                        false
                ) {
                    HStack(
                        spacing:
                            6
                    ) {
                        ForEach(
                            path
                        ) {
                            node in

                            if
                                node.id
                                    != path
                                        .first?
                                        .id
                            {
                                Text(
                                    "›"
                                )
                                .foregroundStyle(
                                    .tertiary
                                )
                            }

                            TestudoDestinationLink(
                                title:
                                    displayTitle(
                                        node
                                    ),
                                destination:
                                    .work(
                                        node.id
                                    ),
                                color:
                                    .secondary
                            )
                        }
                    }
                }
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

                    Button {
                        beginChildComposer(
                            .task
                        )
                    } label: {
                        Image(
                            systemName:
                                "plus.circle"
                        )
            .testudoTaskStatusSymbolColor(
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
                    .buttonStyle(.plain)
                    .help(
                        "Add to this task"
                    )
                    .popover(
                        isPresented:
                            $showingChildComposer,
                        arrowEdge:
                            .top
                    ) {
                        childComposer(
                            parent: item
                        )
                    }
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
                        alignment:
                            .leading,
                        spacing:
                            0
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
                                    alignment:
                                        .top,
                                    spacing:
                                        10
                                ) {
                                    Image(
                                        systemName:
                                            childIcon(
                                                child
                                            )
                                    )
                                    .testudoTaskStatusSymbolColor(
                                        childIcon(
                                            child
                                        )
                                    )
                                    .frame(
                                        width:
                                            18
                                    )
                                    .padding(
                                        .top,
                                        2
                                    )


                                    VStack(
                                        alignment:
                                            .leading,
                                        spacing:
                                            3
                                    ) {
                                        Text(
                                            displayTitle(
                                                child
                                            )
                                        )
                                        .font(
                                            .callout
                                        )
                                        .fontWeight(
                                            .medium
                                        )
                                        .foregroundStyle(
                                            .primary
                                        )


                                        let childBody =
                                            child.body
                                                .trimmingCharacters(
                                                    in:
                                                        .whitespacesAndNewlines
                                                )

                                        let childTitle =
                                            child.title?
                                                .trimmingCharacters(
                                                    in:
                                                        .whitespacesAndNewlines
                                                )
                                            ?? ""


                                        // Show body text as a secondary preview
                                        // for Sub-tasks, Notes and Activities.
                                        //
                                        // If there is no explicit title,
                                        // displayTitle(child) already uses the
                                        // body, so avoid repeating the same
                                        // content a second time.
                                        if
                                            !childBody.isEmpty,
                                            !childTitle.isEmpty
                                        {
                                            Text(
                                                childBody
                                            )
                                            .font(
                                                .caption
                                            )
                                            .foregroundStyle(
                                                .secondary
                                            )
                                            .lineLimit(
                                                2
                                            )
                                            .fixedSize(
                                                horizontal:
                                                    false,
                                                vertical:
                                                    true
                                            )
                                        }


                                        if
                                            child.kind
                                                == .activity,
                                            let occurred =
                                                child.loggedAt
                                        {
                                            Text(
                                                "Occurred \(TestudoTime.displayDateTime(occurred, sourceTimeZoneID: child.loggedTimeZoneID))"
                                            )
                                            .font(
                                                .caption2
                                            )
                                            .foregroundStyle(
                                                .secondary
                                            )
                                        }
                                    }


                                    Spacer(
                                        minLength:
                                            16
                                    )


                                    Text(
                                        childTypeLabel(
                                            child
                                        )
                                    )
                                    .font(
                                        .caption2
                                    )
                                    .foregroundStyle(
                                        .secondary
                                    )
                                    .padding(
                                        .top,
                                        2
                                    )
                                }
                                .padding(
                                    .vertical,
                                    8
                                )
                                .contentShape(
                                    Rectangle()
                                )
                            }
                            .buttonStyle(
                                .plain
                            )


                            if
                                child.id
                                    != children
                                        .last?
                                        .id
                            {
                                Divider()
                                    .padding(
                                        .leading,
                                        28
                                    )
                            }
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
            spacing: 0
        ) {
            // ------------------------------------------------
            // Header
            // ------------------------------------------------

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text("Add to Task")
                    .font(
                        .system(
                            size: 20,
                            weight:
                                .semibold
                        )
                    )

                Text(
                    "Create an item inside “\(displayTitle(parent))”."
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)
            }
            .padding(
                .horizontal,
                24
            )
            .padding(
                .top,
                22
            )

            // ------------------------------------------------
            // Segmented type selector
            // ------------------------------------------------

            Picker(
                "Type",
                selection:
                    $childKindDraft
            ) {
                Text("Sub-task")
                    .tag(
                        WorkItemKind.task
                    )

                Text("Activity")
                    .tag(
                        WorkItemKind.activity
                    )

                Text("Note")
                    .tag(
                        WorkItemKind.note
                    )
            }
            .pickerStyle(
                .segmented
            )
            .labelsHidden()
            .padding(
                .horizontal,
                24
            )
            .padding(
                .top,
                20
            )

            Divider()
                .padding(
                    .top,
                    18
                )

            // ------------------------------------------------
            // Form
            // ------------------------------------------------

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    childTitleField

                    childBodyField

                    switch childKindDraft {
                    case .task:
                        childTaskOptions

                    case .note:
                        childNoteOptions

                    case .activity:
                        childActivityOptions
                    }

                    if let childErrorMessage {
                        HStack(
                            alignment: .top,
                            spacing: 8
                        ) {
                            Image(
                                systemName:
                                    "exclamationmark.circle.fill"
                            )
            .testudoTaskStatusSymbolColor(
                "exclamationmark.circle.fill"
            )
                            .foregroundStyle(
                                .red
                            )

                            Text(
                                childErrorMessage
                            )
                            .font(.callout)
                            .foregroundStyle(
                                .red
                            )

                            Spacer()
                        }
                        .padding(10)
                        .background(
                            Color.red
                                .opacity(0.06),
                            in:
                                RoundedRectangle(
                                    cornerRadius: 8,
                                    style:
                                        .continuous
                                )
                        )
                    }
                }
                .padding(
                    .horizontal,
                    24
                )
                .padding(
                    .vertical,
                    20
                )
            }
            .frame(
                maxHeight: 420
            )

            Divider()

            // ------------------------------------------------
            // Actions
            // ------------------------------------------------

            HStack(
                spacing: 10
            ) {
                Spacer()

                Button(
                    "Cancel"
                ) {
                    cancelChildComposer()
                }
                .keyboardShortcut(
                    .cancelAction
                )

                Button(
                    childAddButtonTitle
                ) {
                    addChild(
                        to: parent
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
                .disabled(
                    !childCanAdd
                )
            }
            .padding(
                .horizontal,
                24
            )
            .padding(
                .vertical,
                16
            )
        }
        .frame(
            width: 520
        )
        .background(
            TestudoStyle
                .contentBackground
        )
    }


    private var childTitleField:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            Text(
                childKindDraft == .note
                ? "Title"
                : "Title"
            )
            .font(
                .caption
                    .weight(.medium)
            )
            .foregroundStyle(
                .secondary
            )

            TextField(
                childKindDraft == .note
                ? "Optional title"
                : (
                    childKindDraft
                        == .activity
                    ? "Activity title"
                    : "Sub-task title"
                ),
                text:
                    $childTitleDraft
            )
            .textFieldStyle(
                .roundedBorder
            )
        }
    }


    private var childBodyField:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 7
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
            .font(
                .caption
                    .weight(.medium)
            )
            .foregroundStyle(
                .secondary
            )

            TextEditor(
                text:
                    $childBodyDraft
            )
            .font(.body)
            .scrollContentBackground(
                .hidden
            )
            .padding(8)
            .frame(
                minHeight: 105
            )
            .background(
                Color(
                    nsColor:
                        .textBackgroundColor
                ),
                in:
                    RoundedRectangle(
                        cornerRadius: 8,
                        style:
                            .continuous
                    )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style:
                        .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.12),
                    lineWidth: 1
                )
            }
        }
    }


    private var childTaskOptions:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            childOptionHeader(
                title:
                    "Task options",
                icon:
                    "checkmark.circle"
            )

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
                    label:
                        "Deadline",
                    date:
                        $childDeadlineDraft,
                    timeZoneID:
                        $childDeadlineTimeZoneID
                )
            }
        }
        .padding(14)
        .background(
            Color.primary
                .opacity(0.025),
            in:
                RoundedRectangle(
                    cornerRadius: 10,
                    style:
                        .continuous
                )
        )
    }


    private var childNoteOptions:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            childOptionHeader(
                title:
                    "Note options",
                icon:
                    "note.text"
            )

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
                    label:
                        "Reminder",
                    date:
                        $childReminderDraft,
                    timeZoneID:
                        $childReminderTimeZoneID
                )
            }
        }
        .padding(14)
        .background(
            Color.primary
                .opacity(0.025),
            in:
                RoundedRectangle(
                    cornerRadius: 10,
                    style:
                        .continuous
                )
        )
    }


    private var childActivityOptions:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                12
        ) {

            childOptionHeader(
                title:
                    "Activity options",
                icon:
                    "clock.arrow.circlepath"
            )


            Toggle(
                "Set date and time",
                isOn:
                    $childHasOccurredAt
            )


            if childHasOccurredAt {

                TimeZoneAwareDateEditor(
                    label:
                        "Occurred",
                    date:
                        $childOccurredAtDraft,
                    timeZoneID:
                        $childOccurredTimeZoneID
                )
            }


            HStack(
                alignment:
                    .top,
                spacing:
                    7
            ) {

                Image(
                    systemName:
                        "info.circle"
                )
                .testudoTaskStatusSymbolColor(
                    "info.circle"
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    "An Activity records something that happened while working on the Task. The date and time are optional. Calendar Events are managed separately in Calendar."
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
            }
        }
        .padding(
            14
        )
        .background(
            Color
                .primary
                .opacity(
                    0.025
                ),
            in:
                RoundedRectangle(
                    cornerRadius:
                        10,
                    style:
                        .continuous
                )
        )
    }


    private func childOptionHeader(
        title: String,
        icon: String
    ) -> some View {
        Label(
            title,
            systemImage:
                icon
        )
        .font(
            .callout
                .weight(.medium)
        )
    }


    private var childCanAdd:
        Bool
    {
        let title =
            childTitleDraft
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        let body =
            childBodyDraft
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        switch childKindDraft {
        case .task:
            return !title.isEmpty
                || !body.isEmpty

        case .note:
            return !title.isEmpty
                || !body.isEmpty

        case .activity:
            return !title.isEmpty
                || !body.isEmpty
        }
    }


    private var childAddButtonTitle:
        String
    {
        switch childKindDraft {
        case .task:
            return "Add Sub-task"

        case .note:
            return "Add Note"

        case .activity:
            return "Add Activity"
        }
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

        childHasOccurredAt =
            false

        childOccurredAtDraft =
            Date()

        childDeadlineTimeZoneID =
            TestudoTime.deviceTimeZoneID

        childReminderTimeZoneID =
            TestudoTime.deviceTimeZoneID

        childOccurredTimeZoneID =
            TestudoTime.deviceTimeZoneID

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
                    && childHasOccurredAt
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
                    && childHasOccurredAt
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
            return "waveform.path.ecg"
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
            return "waveform.path.ecg"
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
            return "Activity"
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

            case .closed:
                return "archivebox"

            case .inProgress:
                return "clock"

            case .todo,
                 nil:
                return "circle"
            }

        case .note:
            return "note.text"

        case .activity:
            return "waveform.path.ecg"
        }
    }

    @ViewBuilder
    private func relationshipsSection(
        _ item: WorkItem
    ) -> some View {
        InspectorSection(
            title:
                "Related People, Groups & Organizations"
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

        let relatedEntities =
            relationships
                .compactMap {
                    store.entity(
                        id:
                            $0.entityID
                    )
                }

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
            .testudoTaskStatusSymbolColor(
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

                } else if
                    !relatedEntities
                        .isEmpty
                {
                    TestudoEntityLinks(
                        entities:
                            relatedEntities,
                        font:
                            .callout,
                        color:
                            .primary
                    )

                } else {
                    Text(
                        relationshipNames(
                            relationships
                        )
                    )
                    .foregroundStyle(
                        .secondary
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
            .testudoTaskStatusSymbolColor(
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
        let directRelationships =
            store.data
                .workEntityRelationships
                .filter {
                    $0.workItemID
                        == item.id
                    && $0.role
                        == role
                }

        let selectedIDs =
            Set(
                directRelationships
                    .map(
                        \.entityID
                    )
            )

        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            EntitySelectionButton(
                title:
                    role.displayName,
                selectedIDs:
                    selectedIDs,
                tabs:
                    [
                        .people,
                        .groups,
                        .organizations
                    ],
                maximumSelectionCount:
                    nil,
                placeholder:
                    "Choose people, groups or organizations…",
                selectorMessage:
                    "Already linked entities appear in Selected at the top. Remove them there, or choose additional People, Groups or Organizations below.",
                onSave: {
                    selection in

                    syncRelationshipSelection(
                        for:
                            item,
                        role:
                            role,
                        selectedIDs:
                            selection
                    )
                }
            )

            Toggle(
                "Inherited by child items for newly added relationships",
                isOn:
                    $newRelationshipInheritedByChildren
            )
            .font(
                .caption
            )

            Text(
                "Existing relationships keep their current inheritance setting. The option above applies only to newly added entities."
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )

            if let errorMessage {
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

            HStack {
                Spacer()

                Button(
                    "Close"
                ) {
                    cancelAddingRelationship()
                }
                .buttonStyle(
                    .borderless
                )
            }
        }
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


    private func syncRelationshipSelection(
        for item: WorkItem,
        role: WorkRelationshipRole,
        selectedIDs: Set<UUID>
    ) -> String? {
        let existing =
            store.data
                .workEntityRelationships
                .filter {
                    $0.workItemID
                        == item.id
                    && $0.role
                        == role
                }

        let existingIDs =
            Set(
                existing.map(
                    \.entityID
                )
            )

        let additions =
            selectedIDs
                .subtracting(
                    existingIDs
                )
                .sorted {
                    $0.uuidString
                        < $1.uuidString
                }

        /*
         Add first.

         If validation fails, we have not removed any existing
         relationship yet.
        */
        for entityID in additions {
            if
                let error =
                    store
                        .addWorkRelationship(
                            workItemID:
                                item.id,
                            entityID:
                                entityID,
                            role:
                                role,
                            inheritedByChildren:
                                newRelationshipInheritedByChildren
                        )
            {
                errorMessage =
                    error

                return error
            }
        }

        /*
         Remove direct relationships that the user unchecked
         in the selector.

         We deliberately operate only on relationships whose
         workItemID is this item, so inherited relationships
         belonging to parent Tasks are never deleted here.
        */
        let removals =
            existing
                .filter {
                    !selectedIDs
                        .contains(
                            $0.entityID
                        )
                }

        for relationship in removals {
            store
                .removeWorkRelationship(
                    relationshipID:
                        relationship.id
                )
        }

        errorMessage =
            nil

        showingRelationshipComposer =
            false

        return nil
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

                    EntitySelectionButton(
                        title:
                            "Related Entity",
                        selectedIDs:
                            relationshipEntityDraft
                                .map {
                                    Set([$0])
                                }
                            ?? [],
                        tabs:
                            [
                                .people,
                                .groups,
                                .organizations
                            ],
                        maximumSelectionCount:
                            1,
                        placeholder:
                            "Choose person, group or organization…",
                        selectorMessage:
                            "Choose the Person, Group or Organization for this relationship.",
                        onSave: {
                            selection in

                            relationshipEntityDraft =
                                selection.first

                            return nil
                        }
                    )

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

                if
                    let relatedEntity =
                        store.entity(
                            id:
                                relationship
                                    .entityID
                        )
                {
                    TestudoEntityLinks(
                        entities:
                            [
                                relatedEntity
                            ],
                        font:
                            .callout,
                        color:
                            .primary
                    )

                } else {
                    Text(
                        "Unknown"
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                }

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
                        TestudoTime
                            .displayDateTime(
                                item.createdAt,
                                sourceTimeZoneID:
                                    item.createdTimeZoneID
                            )
                )

                ReadOnlyInspectorRow(
                    label: "Updated",
                    value:
                        TestudoTime
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
                            TestudoTime
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
                            TestudoTime
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
                            TestudoTime
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
            .testudoTaskStatusSymbolColor(
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
                                    TestudoTime
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
                    "Deadline: \(TestudoTime.displayDateTime(date, sourceTimeZoneID: event.valueTimeZoneID))"
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
            return "Activity"
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
            TestudoTime
                .validTimeZoneIdentifier(
                    timeZoneID
                )
            ?? TestudoTime
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

        case .activityDate:
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

    private func copyPendingParentRelationships() {
        guard
            let parentID =
                pendingParentRelationshipSourceID
        else {
            return
        }


        let error =
            store
                .copyInheritedWorkRelationships(
                    fromParentTaskID:
                        parentID,
                    toWorkItemID:
                        itemID,
                    replacingExisting:
                        true
                )


        pendingParentRelationshipSourceID =
            nil

        showingParentRelationshipChoice =
            false

        errorMessage =
            error
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
    ) -> [WorkItem] {
        var path =
            [
                item
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
                    id:
                        currentID
                )
        {
            visited.insert(
                currentID
            )

            path.insert(
                parent,
                at:
                    0
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
            return "Activity"
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

            case .closed:
                return "archivebox"

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
            return "waveform.path.ecg"
        }
    }

    private func formatted(
        _ date: Date
    ) -> String {
        TestudoTime.dateTime(
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

struct InlineEditButton:
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
    private var store: TestudoStore

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
            TestudoStyle
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
                                        TestudoTime
                                            .dateTime(
                                                theme.createdAt
                                            )
                                )

                                ReadOnlyInspectorRow(
                                    label: "Updated",
                                    value:
                                        TestudoTime
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
    private var store: TestudoStore

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
            TestudoStyle
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
                                        TestudoTime
                                            .dateTime(
                                                entity
                                                    .createdAt
                                            )
                                )

                                ReadOnlyInspectorRow(
                                    label: "Updated",
                                    value:
                                        TestudoTime
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
    private var store: TestudoStore

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
            TestudoStyle
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
                    ) {
                        deleteFooter
                    }
                    .id(
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
                    ) {
                        deleteFooter
                    }
                    .id(
                        selectedWorkItemID
                    )

                } else if
                    section == .themes,
                    let selectedThemeID
                {
                    ThemeRelatedTasksDetailView(
                        themeID:
                            selectedThemeID
                    ) {
                        deleteFooter
                    }
                    .id(
                        selectedThemeID
                    )
                } else if
                    section
                        == .organizations,
                    let selectedOrganizationID
                {
                    OrganizationDetailView(
                        organizationID:
                            selectedOrganizationID
                    ) {
                        deleteFooter
                    }
                    .id(
                        selectedOrganizationID
                    )
                } else if
                    section
                        == .groups,
                    let selectedGroupID
                {
                    GroupDetailView(
                        groupID:
                            selectedGroupID
                    ) {
                        deleteFooter
                    }
                    .id(
                        selectedGroupID
                    )
                } else if
                    section == .people,
                    let selectedPersonID
                {
                    PersonDetailView(
                        personID:
                            selectedPersonID
                    ) {
                        deleteFooter
                    }
                    .id(
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
                    ) {
                        deleteFooter
                    }
                    .id(
                        selectedWorkItemID
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
            TestudoStyle
                .contentBackground
        )

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
                        "This permanently deletes this Calendar Event from Testudo. If it belongs to a synchronized external calendar, the deletion will be queued for synchronization.",
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
            store.environmentMembership(
                linkedToPerson:
                    entity.id
            ) != nil
        {
            return
                "This Person is linked to an Environment membership. The membership must be unlinked before this Person can be deleted."
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
