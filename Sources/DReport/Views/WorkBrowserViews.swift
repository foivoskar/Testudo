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
        Calendar.current
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
                "Reminder \(reminder.formatted(date: .omitted, time: .shortened))"
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
                "Reminder \(reminder.formatted(date: .abbreviated, time: .shortened))"
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
                .font(.headline)

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
            14
        )
        .padding(
            .bottom,
            10
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
                    .padding(28)
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
                    eventDateRow(item)
                    reminderRow(item)
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
                        .map(formatted)
                    ?? "None",
                onEdit: {
                    beginDateEdit(
                        .deadline,
                        date:
                            item.deadlineAt
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
                        .map(formatted)
                    ?? "None",
                onEdit: {
                    beginDateEdit(
                        .reminder,
                        date:
                            item.reminderAt
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func eventDateRow(
        _ item: WorkItem
    ) -> some View {
        if
            editingField
                == .eventDate
        {
            dateEditorRow(
                label: "Event",
                field: .eventDate,
                item: item
            )
        } else {
            EditableValueRow(
                label: "Event",
                value:
                    item.scheduledAt
                        .map(formatted)
                    ?? "None",
                onEdit: {
                    beginDateEdit(
                        .eventDate,
                        date:
                            item.scheduledAt
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
                DatePicker(
                    "",
                    selection:
                        $dateDraft,
                    displayedComponents:
                        [
                            .date,
                            .hourAndMinute
                        ]
                )
                .labelsHidden()
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

        if !children.isEmpty {
            InspectorSection(
                title: "Contains"
            ) {
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
                                        largeIcon(
                                            child
                                        )
                                )
                                .frame(
                                    width: 18
                                )

                                Text(
                                    displayTitle(
                                        child
                                    )
                                )

                                Spacer()

                                Text(
                                    typeLabel(
                                        child
                                    )
                                )
                                .font(
                                    .caption
                                )
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

    @ViewBuilder
    private func relationshipsSection(
        _ item: WorkItem
    ) -> some View {
        let relationships =
            store.data
                .workEntityRelationships
                .filter {
                    $0.workItemID
                        == item.id
                }

        if !relationships.isEmpty {
            InspectorSection(
                title:
                    "Related People & Organizations"
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 9
                ) {
                    ForEach(
                        relationships
                    ) { relationship in
                        relationshipRow(
                            relationship
                        )
                    }
                }
            }
        }
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
        InspectorSection(
            title: "History"
        ) {
            VStack(spacing: 9) {
                ReadOnlyInspectorRow(
                    label: "Created",
                    value:
                        formatted(
                            item.createdAt
                        )
                )

                ReadOnlyInspectorRow(
                    label: "Updated",
                    value:
                        formatted(
                            item.updatedAt
                        )
                )

                if
                    let started =
                        item.startedAt
                {
                    ReadOnlyInspectorRow(
                        label: "Started",
                        value:
                            formatted(
                                started
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
                            formatted(
                                completed
                            )
                    )
                }

                if
                    let logged =
                        item.loggedAt
                {
                    ReadOnlyInspectorRow(
                        label: "Logged",
                        value:
                            formatted(
                                logged
                            )
                    )
                }
            }
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
        date: Date?
    ) {
        editingField = field

        dateEnabledDraft =
            date != nil

        dateDraft =
            date
            ?? Calendar.current.date(
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
                    reminderWasEdited:
                        true
                )
            )

        case .eventDate:
            finish(
                update(
                    item,
                    scheduled:
                        value,
                    scheduledWasEdited:
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
        deadlineWasEdited: Bool = false,
        reminder: Date? = nil,
        reminderWasEdited: Bool = false,
        scheduled: Date? = nil,
        scheduledWasEdited: Bool = false
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
                item.kind == .activity
                ? (
                    scheduledWasEdited
                    ? scheduled
                    : item.scheduledAt
                )
                : nil
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
        date.formatted(
            date: .abbreviated,
            time: .shortened
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

struct WorkDetailRouterView: View {
    let section: SidebarSection

    @Binding
    var selectedWorkItemID: UUID?

    @Binding
    var selectedPersonID: UUID?

    var body: some View {
        ZStack {
            DReportStyle
                .contentBackground
                .ignoresSafeArea()

            Group {
                if
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
}
