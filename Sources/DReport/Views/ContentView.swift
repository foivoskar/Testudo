import SwiftUI

enum SidebarSection:
    String,
    CaseIterable,
    Identifiable
{
    case today
    case allTasks
    case todo
    case inProgress
    case completed
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
        case .today:
            return "Today"
        case .allTasks:
            return "All Tasks"
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
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
        case .today:
            return "calendar"
        case .allTasks:
            return "list.bullet.indent"
        case .todo:
            return "circle"
        case .inProgress:
            return "clock"
        case .completed:
            return "checkmark.circle"
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

struct ContentView: View {
    @State
    private var selection:
        SidebarSection? = .today

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Section("Work") {
                        ForEach(
                            SidebarSection.allCases.filter {
                                ![
                                    "themes",
                                    "organizations",
                                    "groups",
                                    "people"
                                ].contains($0.rawValue)
                            }
                        ) { item in
                            Label(
                                item.title,
                                systemImage: item.icon
                            )
                            .tag(item)
                            .padding(.vertical, 1)
                        }
                    }

                    Section("Structure") {
                        ForEach(
                            SidebarSection.allCases.filter {
                                [
                                    "themes",
                                    "organizations",
                                    "groups",
                                    "people"
                                ].contains($0.rawValue)
                            }
                        ) { item in
                            Label(
                                item.title,
                                systemImage: item.icon
                            )
                            .tag(item)
                            .padding(.vertical, 1)
                        }
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
                    selection ?? .today
            )
            .background(
                DReportStyle.contentBackground
            )
            .navigationSplitViewColumnWidth(
                min: 330,
                ideal: 390,
                max: 560
            )
        } detail: {
            DetailPlaceholderView()
                .background(
                    DReportStyle.contentBackground
                )
                .navigationSplitViewColumnWidth(
                    min: 420,
                    ideal: 650
                )
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct SectionContentView: View {
    @EnvironmentObject
    private var store: DReportStore

    let section: SidebarSection

    @State
    private var showingCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
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
                            DReportStyle.secondaryText
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
            .padding(.top, 7)
            .padding(.bottom, 7)
            .frame(minHeight: 48)
            .background(
                DReportStyle.headerBackground
            )

            Divider()

            sectionBody
                .background(
                    DReportStyle.contentBackground
                )
        }
        .sheet(
            isPresented:
                $showingCreateSheet
        ) {
            createSheet
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
        case .today:
            TodayView()

        case .allTasks:
            AllTasksView()

        case .todo:
            StatusTaskListView(
                status: .todo
            )

        case .inProgress:
            StatusTaskListView(
                status: .inProgress
            )

        case .completed:
            StatusTaskListView(
                status: .completed
            )

        case .timeline:
            TimelineView()

        case .themes:
            ThemeListView()

        case .organizations:
            EntityListView(
                kind: .organization
            )

        case .groups:
            EntityListView(
                kind: .group
            )

        case .people:
            EntityListView(
                kind: .person
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
    private var store: DReportStore

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
                        theme: theme
                    )
                }
            }
        }
    }
}

private struct ThemeNodeView: View {
    @EnvironmentObject
    private var store: DReportStore

    let theme: Theme

    @State
    private var isExpanded = true

    @State
    private var createKind:
        WorkItemKind?

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
                    item: item
                )
            }

            ForEach(
                store.childThemes(
                    of: theme.id
                )
            ) { child in
                ThemeNodeView(
                    theme: child
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
        .contextMenu {
            Button(
                "Delete Theme",
                role: .destructive
            ) {
                store.deleteTheme(
                    id: theme.id
                )
            }
        }
    }
}

private struct WorkItemNodeView: View {
    @EnvironmentObject
    private var store: DReportStore

    let item: WorkItem

    @State
    private var isExpanded = true

    @State
    private var createKind:
        WorkItemKind?

    var body: some View {
        let children =
            store.childWorkItems(
                of: item.id
            )

        if children.isEmpty {
            label
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
                        item: child
                    )
                }
            } label: {
                label
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

    private var label: some View {
        HStack(spacing: 8) {
            Image(
                systemName: itemIcon
            )
            .foregroundStyle(
                item.kind == .task
                ? .primary
                : .secondary
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
                        .secondary
                    )

                    if let deadline =
                        item.deadlineAt
                    {
                        Text(
                            "Deadline: \(deadline.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            deadline < Date()
                            && status != .completed
                            ? .red
                            : .secondary
                        )
                    }
                } else {
                    Text(
                        item.kind.displayName
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
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

        Divider()

        Button(
            "Delete",
            role: .destructive
        ) {
            store.deleteWorkItem(
                id: item.id
            )
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
    private var store: DReportStore

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
    private var store: DReportStore

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
    private var store: DReportStore

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
    private var store: DReportStore

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
        }
    }
}

private struct TodayView: View {
    @EnvironmentObject
    private var store: DReportStore

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
    private var store: DReportStore

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
    private var store: DReportStore

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
    private var store: DReportStore

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
                    DatePicker(
                        "Due",
                        selection: $deadlineAt,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
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
    private var store: DReportStore

    let kind: EntityKind

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
            List(entities) { entity in
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
                .contextMenu {
                    Button(
                        "Delete",
                        role: .destructive
                    ) {
                        store.deleteEntity(
                            id: entity.id
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
    private var store: DReportStore

    @Binding
    var isPresented: Bool

    @State
    private var name = ""

    @State
    private var parentID: UUID?

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
    private var store: DReportStore

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

private struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
            }
            .frame(height: 48)
            .background(
                DReportStyle.headerBackground
            )

            ZStack {
                DReportStyle.contentBackground

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
    private var store: DReportStore

    var body: some View {
        Form {
            Section("DReport") {
                LabeledContent(
                    "Storage"
                ) {
                    Text("Local")
                }

                LabeledContent(
                    "Accounts"
                ) {
                    Text("None")
                }
            }

            Section("Data") {
                Text(
                    store.fileURL.path
                )
                .font(.caption)
                .textSelection(.enabled)
            }
        }
        .padding()
        .frame(width: 540)
    }
}
