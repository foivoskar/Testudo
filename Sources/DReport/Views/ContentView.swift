import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case today
    case todo
    case inProgress
    case completed
    case timeline
    case themes
    case organizations
    case groups
    case people

    var id: String { rawValue }

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
    @State private var selection: SidebarSection? = .today

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("DReport")
            .navigationSplitViewColumnWidth(
                min: 180,
                ideal: 215,
                max: 280
            )
        } content: {
            WorkBrowserView(section: selection ?? .today)
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

private struct WorkBrowserView: View {
    let section: SidebarSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            ContentUnavailableView {
                Label(emptyTitle, systemImage: section.icon)
            } description: {
                Text(emptyDescription)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var subtitle: String {
        switch section {
        case .today:
            return "Scheduled work and activity recorded today"
        case .todo:
            return "Tasks waiting to be started"
        case .inProgress:
            return "Work currently in progress"
        case .completed:
            return "Completed work"
        case .timeline:
            return "Chronological history of your work"
        case .themes:
            return "Hierarchical areas of work"
        case .organizations:
            return "Organizations and sub-organizations"
        case .groups:
            return "Groups inside or outside organizations"
        case .people:
            return "People related to your work"
        }
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
        case .themes:
            return "No Themes Yet"
        case .organizations:
            return "No Organizations Yet"
        case .groups:
            return "No Groups Yet"
        case .people:
            return "No People Yet"
        }
    }

    private var emptyDescription: String {
        switch section {
        case .today:
            return "Activity recorded today will appear here."
        case .todo, .inProgress, .completed:
            return "Tasks with this status will appear here."
        case .timeline:
            return "DReport will build a chronological record as you work."
        case .themes:
            return "Create themes to organize different areas of work."
        case .organizations:
            return "Create organizations and their relationships."
        case .groups:
            return "Groups may belong to organizations or remain independent."
        case .people:
            return "People may belong to multiple organizations or groups."
        }
    }
}

private struct DetailPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nothing Selected", systemImage: "doc.text")
        } description: {
            Text(
                "Select a task, note, activity entry, theme, organization, group or person."
            )
        }
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("DReport") {
                LabeledContent("Storage") {
                    Text("Local")
                }

                LabeledContent("Accounts") {
                    Text("None")
                }

                Text(
                    "DReport keeps its data locally and contains no user-specific defaults."
                )
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
