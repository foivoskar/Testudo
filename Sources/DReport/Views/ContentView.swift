import SwiftUI

enum SidebarSection:
    String,
    CaseIterable,
    Identifiable
{
    case today
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
            List(
                SidebarSection.allCases,
                selection: $selection
            ) { item in
                Label(
                    item.title,
                    systemImage: item.icon
                )
                .tag(item)
            }
            .navigationTitle("DReport")
            .navigationSplitViewColumnWidth(
                min: 180,
                ideal: 215,
                max: 280
            )
        } content: {
            SectionContentView(
                section:
                    selection ?? .today
            )
            .navigationSplitViewColumnWidth(
                min: 340,
                ideal: 480
            )
        } detail: {
            DetailPlaceholderView()
                .navigationSplitViewColumnWidth(
                    min: 320,
                    ideal: 430
                )
        }
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
            header

            Divider()

            sectionBody
        }
        .sheet(
            isPresented:
                $showingCreateSheet
        ) {
            createSheet
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            if canCreate {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label(
                        "New",
                        systemImage: "plus"
                    )
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
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

        default:
            genericEmptyView
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

    private var subtitle: String {
        switch section {
        case .today:
            return
                "Scheduled work and activity recorded today"

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
                "Hierarchical areas of work"

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

    private var genericEmptyView: some View {
        ContentUnavailableView {
            Label(
                emptyTitle,
                systemImage:
                    section.icon
            )
        } description: {
            Text(emptyDescription)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private var emptyTitle: String {
        switch section {
        case .today:
            return "No Activity Yet"
        case .todo:
            return "No Tasks To Do"
        case .inProgress:
            return "Nothing In Progress"
        case .completed:
            return "No Completed Tasks"
        case .timeline:
            return "No History Yet"
        default:
            return "Nothing Here Yet"
        }
    }

    private var emptyDescription: String {
        switch section {
        case .today:
            return
                "Activity recorded today will appear here."

        case .todo,
             .inProgress,
             .completed:
            return
                "Tasks with this status will appear here."

        case .timeline:
            return
                "DReport will build a chronological record as you work."

        default:
            return ""
        }
    }
}

private struct ThemeListView: View {
    @EnvironmentObject
    private var store: DReportStore

    var body: some View {
        if store.data.themes.isEmpty {
            ContentUnavailableView {
                Label(
                    "No Themes Yet",
                    systemImage:
                        "square.stack.3d.up"
                )
            } description: {
                Text(
                    "Create a theme to define an area of work."
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            List {
                ForEach(themeRows) { row in
                    HStack(spacing: 8) {
                        Image(
                            systemName:
                                "folder"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Text(row.theme.name)

                        Spacer()
                    }
                    .padding(
                        .leading,
                        CGFloat(row.depth) * 20
                    )
                    .contextMenu {
                        Button(
                            "Delete",
                            role: .destructive
                        ) {
                            store.deleteTheme(
                                id:
                                    row.theme.id
                            )
                        }
                    }
                }
            }
        }
    }

    private var themeRows:
        [ThemeRow]
    {
        var result: [ThemeRow] = []

        let roots =
            store.data.themes
                .filter {
                    $0.parentThemeID == nil
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

        for root in roots {
            appendTheme(
                root,
                depth: 0,
                to: &result
            )
        }

        return result
    }

    private func appendTheme(
        _ theme: Theme,
        depth: Int,
        to result:
            inout [ThemeRow]
    ) {
        result.append(
            ThemeRow(
                theme: theme,
                depth: depth
            )
        )

        let children =
            store.data.themes
                .filter {
                    $0.parentThemeID
                    == theme.id
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

        for child in children {
            appendTheme(
                child,
                depth: depth + 1,
                to: &result
            )
        }
    }
}

private struct ThemeRow: Identifiable {
    let theme: Theme
    let depth: Int

    var id: UUID {
        theme.id
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
                        Text(
                            "Independent"
                        )
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
        ContentUnavailableView {
            Label(
                "Nothing Selected",
                systemImage: "doc.text"
            )
        } description: {
            Text(
                "Select a task, note, activity entry, theme, organization, group or person."
            )
        }
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
