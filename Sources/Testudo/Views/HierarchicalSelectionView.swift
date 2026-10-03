import SwiftUI


// ============================================================
// MARK: - Hierarchical selection node
// ============================================================

struct HierarchySelectionNode:
    Identifiable,
    Hashable
{
    let id:
        String

    /*
     nil means that this row is structural only:
     e.g. an Organization used to group People.
    */
    let selectionID:
        UUID?

    let parentID:
        String?

    let title:
        String

    let subtitle:
        String?

    let systemImage:
        String?


    var systemImageColor:
        Color? = nil

    let depth:
        Int

    let searchText:
        String
}


// ============================================================
// MARK: - Inspector summary + pop-up
// ============================================================

struct HierarchicalSelectionSummaryRow:
    View
{
    let label:
        String

    let selectedTitles:
        [String]

    let selectorTitle:
        String

    var selectorMessage:
        String? = nil

    let nodes:
        [HierarchySelectionNode]

    let initialSelection:
        Set<UUID>

    var buttonSystemImage:
        String = "plus.circle"

    var maximumSelectionCount:
        Int? = nil

    let onSave:
        (Set<UUID>) -> String?


    @State
    private var showingSelector =
        false


    var body: some View {
        DetailSelectionRow(
            label:
                label,
            valueText:
                summaryText,
            valueIsEmpty:
                selectedTitles.isEmpty,
            buttonSystemImage:
                buttonSystemImage,
            helpText:
                "Edit \(label)",
            isPresented:
                $showingSelector,
            onEdit: {
                showingSelector =
                    true
            }
        ) {
            HierarchicalSelectionPanel(
                title:
                    selectorTitle,
                message:
                    selectorMessage,
                nodes:
                    nodes,
                initialSelection:
                    initialSelection,
                maximumSelectionCount:
                    maximumSelectionCount,
                onCancel: {
                    showingSelector =
                        false
                },
                onSave: {
                    selection in

                    let error =
                        onSave(
                            selection
                        )

                    if error == nil {
                        showingSelector =
                            false
                    }

                    return error
                }
            )
            .id(selectionIdentity)
        }
    }


    private var summaryText:
        String
    {
        guard
            !selectedTitles.isEmpty
        else {
            return "None"
        }

        if selectedTitles.count <= 3 {
            return selectedTitles
                .joined(
                    separator: ", "
                )
        }

        let first =
            selectedTitles
                .prefix(3)
                .joined(
                    separator: ", "
                )

        return
            "\(first) +\(selectedTitles.count - 3) more"
    }


    private var selectionIdentity:
        String
    {
        initialSelection
            .map(\.uuidString)
            .sorted()
            .joined(
                separator: "|"
            )
    }
}


// ============================================================
// MARK: - Pop-up panel
// ============================================================

private struct HierarchicalSelectionPanel:
    View
{
    let title:
        String

    let message:
        String?

    let nodes:
        [HierarchySelectionNode]

    let maximumSelectionCount:
        Int?

    let onCancel:
        () -> Void

    let onSave:
        (Set<UUID>) -> String?


    @State
    private var searchText =
        ""

    @State
    private var selection:
        Set<UUID>

    @State
    private var errorMessage:
        String?


    init(
        title:
            String,
        message:
            String?,
        nodes:
            [HierarchySelectionNode],
        initialSelection:
            Set<UUID>,
        maximumSelectionCount:
            Int?,
        onCancel:
            @escaping () -> Void,
        onSave:
            @escaping (Set<UUID>) -> String?
    ) {
        self.title =
            title

        self.message =
            message

        self.nodes =
            nodes

        self.maximumSelectionCount =
            maximumSelectionCount

        self.onCancel =
            onCancel

        self.onSave =
            onSave

        self._selection =
            State(
                initialValue:
                    initialSelection
            )
    }


    var body: some View {
        VStack(
            alignment:
                .leading,
            spacing:
                16
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    5
            ) {
                Text(title)
                    .font(.title3)
                    .fontWeight(
                        .semibold
                    )

                if
                    let message,
                    !message.isEmpty
                {
                    Text(message)
                        .font(.callout)
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

            TextField(
                "Search",
                text:
                    $searchText
            )
            .textFieldStyle(
                .roundedBorder
            )

            Divider()

            if nodes.isEmpty {
                ContentUnavailableView(
                    "Nothing Available",
                    systemImage:
                        "list.bullet"
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else if visibleNodes.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage:
                        "magnifyingglass"
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
                )

            } else {
                ScrollView {
                    LazyVStack(
                        alignment:
                            .leading,
                        spacing:
                            2
                    ) {
                        ForEach(
                            visibleNodes
                        ) { node in
                            nodeRow(node)
                        }
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
                .frame(
                    maxHeight:
                        .infinity
                )
            }

            Divider()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(
                        .red
                    )
            }

            HStack {
                Text(
                    "\(selection.count) selected"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Button(
                    "Cancel",
                    action:
                        onCancel
                )

                Button("Save") {
                    errorMessage =
                        onSave(
                            selection
                        )
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
        }
        .padding(20)
        .frame(
            width: 620,
            height: 650
        )
    }


    @ViewBuilder
    private func nodeRow(
        _ node:
            HierarchySelectionNode
    ) -> some View {
        HStack(
            spacing:
                8
        ) {
            if
                let selectionID =
                    node.selectionID
            {
                Toggle(
                    "",
                    isOn:
                        selectionBinding(
                            selectionID
                        )
                )
                .labelsHidden()
                .toggleStyle(
                    .checkbox
                )
                .frame(
                    width: 18
                )

            } else {
                Image(
                    systemName:
                        "chevron.down"
                )
                .font(
                    .system(
                        size: 8,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .tertiary
                )
                .frame(
                    width: 18
                )
            }

            if
                let systemImage =
                    node.systemImage
            {
                Image(
                    systemName:
                        systemImage
                )
                .foregroundStyle(
                        node.systemImageColor
                        ?? (
                            .secondary
                        )
                    )
                .frame(
                    width: 18
                )
            }

            VStack(
                alignment:
                    .leading,
                spacing:
                    1
            ) {
                Text(node.title)
                    .fontWeight(
                        node.selectionID == nil
                        ? .medium
                        : .regular
                    )
                    .lineLimit(1)

                if
                    let subtitle =
                        node.subtitle,
                    !subtitle.isEmpty
                {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(
            .leading,
            CGFloat(
                min(
                    node.depth,
                    8
                )
            ) * 14
        )
        .padding(
            .vertical,
            4
        )
        .contentShape(
            Rectangle()
        )
        .onTapGesture {
            guard
                let selectionID =
                    node.selectionID
            else {
                return
            }

            if selection.contains(
                selectionID
            ) {
                selection.remove(
                    selectionID
                )
            } else if
                maximumSelectionCount
                    == 1
            {
                selection =
                    Set(
                        [selectionID]
                    )
            } else {
                selection.insert(
                    selectionID
                )
            }
        }
    }


    private func selectionBinding(
        _ id: UUID
    ) -> Binding<Bool> {
        Binding(
            get: {
                selection.contains(id)
            },
            set: {
                enabled in

                if enabled {
                    if
                        maximumSelectionCount
                            == 1
                    {
                        selection =
                            Set([id])
                    } else {
                        selection.insert(id)
                    }
                } else {
                    selection.remove(id)
                }
            }
        )
    }


    private var visibleNodes:
        [HierarchySelectionNode]
    {
        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !query.isEmpty
        else {
            return nodes
        }

        let byID =
            Dictionary(
                uniqueKeysWithValues:
                    nodes.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        var included =
            Set(
                nodes
                    .filter {
                        $0.searchText
                            .lowercased()
                            .contains(
                                query
                            )
                        || $0.title
                            .lowercased()
                            .contains(
                                query
                            )
                    }
                    .map(\.id)
            )

        let directMatches =
            included

        // Keep all ancestors of search matches,
        // so the hierarchy remains understandable.
        var queue =
            Array(
                included
            )

        while
            let currentID =
                queue.popLast()
        {
            guard
                let parentID =
                    byID[currentID]?
                        .parentID
            else {
                continue
            }

            if included.insert(
                parentID
            ).inserted {
                queue.append(
                    parentID
                )
            }
        }

        // If a structural/non-selectable container itself
        // matches the search, show all of its descendants.
        var descendantQueue =
            Array(
                directMatches
                    .filter {
                        byID[$0]?
                            .selectionID
                            == nil
                    }
            )

        while
            let parentID =
                descendantQueue
                    .popLast()
        {
            let children =
                nodes.filter {
                    $0.parentID
                        == parentID
                }

            for child in children {
                if included.insert(
                    child.id
                ).inserted {
                    descendantQueue
                        .append(
                            child.id
                        )
                }
            }
        }

        return nodes.filter {
            included.contains(
                $0.id
            )
        }
    }
}


// ============================================================
// MARK: - Hierarchy builders
// ============================================================

@MainActor
enum HierarchySelectionData {

    // --------------------------------------------------------
    // Tasks / Sub-tasks
    // --------------------------------------------------------

    static func taskNodes(
        store: TestudoStore,
        excludingWorkItemIDs:
            Set<UUID> = []
    ) -> [HierarchySelectionNode] {
        let tasks =
            store.data.workItems
                .filter {
                    $0.kind == .task
                    && !excludingWorkItemIDs
                        .contains(
                            $0.id
                        )
                }

        let taskIDs =
            Set(
                tasks.map(\.id)
            )

        let byID =
            Dictionary(
                uniqueKeysWithValues:
                    tasks.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )

        let roots =
            tasks
                .filter {
                    guard
                        let parentID =
                            $0.parentWorkItemID
                    else {
                        return true
                    }

                    return
                        !taskIDs.contains(
                            parentID
                        )
                }
                .sorted { workSort($0, $1) }

        var result:
            [HierarchySelectionNode] = []

        var visited =
            Set<UUID>()


        func appendTree(
            _ item: WorkItem,
            depth: Int,
            parentNodeID: String?
        ) {
            guard
                visited.insert(
                    item.id
                ).inserted
            else {
                return
            }

            let nodeID =
                "work:\(item.id.uuidString)"

            result.append(
                HierarchySelectionNode(
                    id:
                        nodeID,
                    selectionID:
                        item.id,
                    parentID:
                        parentNodeID,
                    title:
                        workTitle(item),
                    subtitle:
                        nil,
                    systemImage:
                        "checkmark.circle",
                    depth:
                        depth,
                    searchText:
                        workTitle(item)
                )
            )

            let children =
                tasks
                    .filter {
                        $0.parentWorkItemID
                            == item.id
                    }
                    .sorted { workSort($0, $1) }

            for child in children {
                appendTree(
                    child,
                    depth:
                        depth + 1,
                    parentNodeID:
                        nodeID
                )
            }
        }


        for root in roots {
            appendTree(
                root,
                depth: 0,
                parentNodeID: nil
            )
        }

        // Defensive handling for malformed cycles/orphans.
        for task in
            tasks.sorted { workSort($0, $1) }
        {
            if
                !visited.contains(
                    task.id
                )
            {
                appendTree(
                    task,
                    depth: 0,
                    parentNodeID: nil
                )
            }
        }

        _ = byID

        return result
    }


    // --------------------------------------------------------
    // Themes / Sub-themes
    // --------------------------------------------------------

    static func themeNodes(
        store: TestudoStore
    ) -> [HierarchySelectionNode] {
        let themes =
            store.data.themes

        let themeIDs =
            Set(
                themes.map(\.id)
            )

        let roots =
            themes
                .filter {
                    guard
                        let parentID =
                            $0.parentThemeID
                    else {
                        return true
                    }

                    return
                        !themeIDs.contains(
                            parentID
                        )
                }
                .sorted {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }

        var result:
            [HierarchySelectionNode] = []

        var visited =
            Set<UUID>()


        func appendTree(
            _ theme: Theme,
            depth: Int,
            parentNodeID: String?
        ) {
            guard
                visited.insert(
                    theme.id
                ).inserted
            else {
                return
            }

            let nodeID =
                "theme:\(theme.id.uuidString)"

            result.append(
                HierarchySelectionNode(
                    id:
                        nodeID,
                    selectionID:
                        theme.id,
                    parentID:
                        parentNodeID,
                    title:
                        theme.name,
                    subtitle:
                        nil,
                    systemImage:
                        "tag",
                    depth:
                        depth,
                    searchText:
                        theme.name
                )
            )

            let children =
                themes
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
                appendTree(
                    child,
                    depth:
                        depth + 1,
                    parentNodeID:
                        nodeID
                )
            }
        }


        for root in roots {
            appendTree(
                root,
                depth: 0,
                parentNodeID: nil
            )
        }

        for theme in
            themes.sorted(
                by: {
                    $0.name
                        .localizedCaseInsensitiveCompare(
                            $1.name
                        )
                        == .orderedAscending
                }
            )
        {
            if
                !visited.contains(
                    theme.id
                )
            {
                appendTree(
                    theme,
                    depth: 0,
                    parentNodeID: nil
                )
            }
        }

        return result
    }


    // --------------------------------------------------------
    // Organizations / Groups / structural containers
    // --------------------------------------------------------

    static func entityNodes(
        store: TestudoStore,
        candidates: [Entity]
    ) -> [HierarchySelectionNode] {
        let candidateIDs =
            Set(
                candidates.map(\.id)
            )

        let byID =
            Dictionary(
                uniqueKeysWithValues:
                    candidates.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )


        func parentID(
            for entityID: UUID
        ) -> UUID? {
            let possible =
                store.data.memberships
                    .filter {
                        $0.memberEntityID
                            == entityID
                        && candidateIDs
                            .contains(
                                $0.containerEntityID
                            )
                    }

            return
                possible
                    .first(
                        where: {
                            $0.isPrimary
                        }
                    )?
                    .containerEntityID
                ?? possible.first?
                    .containerEntityID
        }


        let parents =
            Dictionary(
                uniqueKeysWithValues:
                    candidates.map {
                        (
                            $0.id,
                            parentID(
                                for:
                                    $0.id
                            )
                        )
                    }
            )

        let roots =
            candidates
                .filter {
                    parents[$0.id]
                        ?? nil
                        == nil
                }
                .sorted { entitySort($0, $1) }

        var result:
            [HierarchySelectionNode] = []

        var visited =
            Set<UUID>()


        func appendTree(
            _ entity: Entity,
            depth: Int,
            parentNodeID: String?
        ) {
            guard
                visited.insert(
                    entity.id
                ).inserted
            else {
                return
            }

            let nodeID =
                "entity:\(entity.id.uuidString)"

            result.append(
                HierarchySelectionNode(
                    id:
                        nodeID,
                    selectionID:
                        entity.id,
                    parentID:
                        parentNodeID,
                    title:
                        entity.name,
                    subtitle:
                        entity.kind
                            .displayName,
                    systemImage:
                        entityIcon(
                            entity.kind
                        ),
                    depth:
                        depth,
                    searchText:
                        "\(entity.name) \(entity.kind.displayName)"
                )
            )

            let children =
                candidates
                    .filter {
                        (
                            parents[$0.id]
                            ?? nil
                        )
                            == entity.id
                    }
                    .sorted { entitySort($0, $1) }

            for child in children {
                appendTree(
                    child,
                    depth:
                        depth + 1,
                    parentNodeID:
                        nodeID
                )
            }
        }


        for root in roots {
            appendTree(
                root,
                depth: 0,
                parentNodeID: nil
            )
        }

        for entity in
            candidates.sorted { entitySort($0, $1) }
        {
            if
                !visited.contains(
                    entity.id
                )
            {
                appendTree(
                    entity,
                    depth: 0,
                    parentNodeID: nil
                )
            }
        }

        _ = byID

        return result
    }


    // --------------------------------------------------------
    // People grouped under existing Organization/Group tree
    // --------------------------------------------------------

    static func peopleNodes(
        store: TestudoStore
    ) -> [HierarchySelectionNode] {
        let people =
            store.data.entities
                .filter {
                    $0.kind == .person
                }

        let containers =
            store.data.entities
                .filter {
                    $0.kind
                        == .organization
                    || $0.kind
                        == .group
                }

        let containerIDs =
            Set(
                containers.map(\.id)
            )


        func structuralParent(
            of entityID: UUID
        ) -> UUID? {
            let memberships =
                store.data.memberships
                    .filter {
                        $0.memberEntityID
                            == entityID
                        && containerIDs
                            .contains(
                                $0.containerEntityID
                            )
                    }

            return
                memberships
                    .first(
                        where: {
                            $0.isPrimary
                        }
                    )?
                    .containerEntityID
                ?? memberships.first?
                    .containerEntityID
        }


        let containerParents =
            Dictionary(
                uniqueKeysWithValues:
                    containers.map {
                        (
                            $0.id,
                            structuralParent(
                                of:
                                    $0.id
                            )
                        )
                    }
            )


        let personContainer =
            Dictionary(
                uniqueKeysWithValues:
                    people.map {
                        person in

                        let memberships =
                            store.data.memberships
                                .filter {
                                    $0.memberEntityID
                                        == person.id
                                    && containerIDs
                                        .contains(
                                            $0.containerEntityID
                                        )
                                }

                        let chosen =
                            memberships
                                .first(
                                    where: {
                                        $0.isPrimary
                                    }
                                )?
                                .containerEntityID
                            ?? memberships
                                .first?
                                .containerEntityID

                        return (
                            person.id,
                            chosen
                        )
                    }
            )


        func peopleAssigned(
            to id: UUID
        ) -> [Entity] {
            people
                .filter {
                    (
                        personContainer[$0.id]
                        ?? nil
                    )
                        == id
                }
                .sorted {
                    personSort(
                        $0,
                        $1,
                        store:
                            store
                    )
                }
        }


        func childContainers(
            of id: UUID
        ) -> [Entity] {
            containers
                .filter {
                    (
                        containerParents[$0.id]
                        ?? nil
                    )
                        == id
                }
                .sorted {
                    personSort(
                        $0,
                        $1,
                        store:
                            store
                    )
                }
        }


        var hasPeopleMemo:
            [UUID: Bool] = [:]


        func hasPeople(
            _ id: UUID,
            visiting:
                Set<UUID> = []
        ) -> Bool {
            if
                let cached =
                    hasPeopleMemo[id]
            {
                return cached
            }

            if visiting.contains(id) {
                return false
            }

            if
                !peopleAssigned(
                    to: id
                ).isEmpty
            {
                hasPeopleMemo[id] =
                    true

                return true
            }

            var nextVisiting =
                visiting

            nextVisiting.insert(id)

            for child in
                childContainers(
                    of: id
                )
            {
                if
                    hasPeople(
                        child.id,
                        visiting:
                            nextVisiting
                    )
                {
                    hasPeopleMemo[id] =
                        true

                    return true
                }
            }

            hasPeopleMemo[id] =
                false

            return false
        }


        let roots =
            containers
                .filter {
                    (
                        containerParents[$0.id]
                        ?? nil
                    )
                        == nil
                }
                .sorted {
                    personSort(
                        $0,
                        $1,
                        store:
                            store
                    )
                }

        var result:
            [HierarchySelectionNode] = []

        var visitedContainers =
            Set<UUID>()


        func appendContainer(
            _ container: Entity,
            depth: Int,
            parentNodeID: String?
        ) {
            guard
                visitedContainers
                    .insert(
                        container.id
                    )
                    .inserted
            else {
                return
            }

            guard
                hasPeople(
                    container.id
                )
            else {
                return
            }

            let nodeID =
                "people-container:\(container.id.uuidString)"

            result.append(
                HierarchySelectionNode(
                    id:
                        nodeID,
                    selectionID:
                        nil,
                    parentID:
                        parentNodeID,
                    title:
                        container.name,
                    subtitle:
                        container.kind
                            .displayName,
                    systemImage:
                        entityIcon(
                            container.kind
                        ),
                    depth:
                        depth,
                    searchText:
                        "\(container.name) \(container.kind.displayName)"
                )
            )

            for child in
                childContainers(
                    of:
                        container.id
                )
            {
                appendContainer(
                    child,
                    depth:
                        depth + 1,
                    parentNodeID:
                        nodeID
                )
            }

            for person in
                peopleAssigned(
                    to:
                        container.id
                )
            {
                let affiliations =
                    store.containers(
                        for:
                            person.id
                    )
                    .map(\.name)
                    .joined(
                        separator: " "
                    )

                result.append(
                    HierarchySelectionNode(
                        id:
                            "person:\(person.id.uuidString)",
                        selectionID:
                            person.id,
                        parentID:
                            nodeID,
                        title:
                            person.name,
                        subtitle:
                            nil,
                        systemImage:
                            "person",
                        depth:
                            depth + 1,
                        searchText:
                            "\(person.name) \(affiliations)"
                    )
                )
            }
        }


        for root in roots {
            appendContainer(
                root,
                depth: 0,
                parentNodeID: nil
            )
        }

        for container in
            containers.sorted { entitySort($0, $1) }
        {
            if
                !visitedContainers
                    .contains(
                        container.id
                    ),
                hasPeople(
                    container.id
                )
            {
                appendContainer(
                    container,
                    depth: 0,
                    parentNodeID: nil
                )
            }
        }


        let unaffiliated =
            people
                .filter {
                    (
                        personContainer[$0.id]
                        ?? nil
                    )
                        == nil
                }
                .sorted {
                    personSort(
                        $0,
                        $1,
                        store:
                            store
                    )
                }

        if !unaffiliated.isEmpty {
            let headingID =
                "people-unaffiliated"

            result.append(
                HierarchySelectionNode(
                    id:
                        headingID,
                    selectionID:
                        nil,
                    parentID:
                        nil,
                    title:
                        "Unaffiliated People",
                    subtitle:
                        nil,
                    systemImage:
                        "person.2",
                    depth:
                        0,
                    searchText:
                        "Unaffiliated People"
                )
            )

            for person in unaffiliated {
                result.append(
                    HierarchySelectionNode(
                        id:
                            "person:\(person.id.uuidString)",
                        selectionID:
                            person.id,
                        parentID:
                            headingID,
                        title:
                            person.name,
                        subtitle:
                            nil,
                        systemImage:
                            "person",
                        depth:
                            1,
                        searchText:
                            person.name
                    )
                )
            }
        }

        return result
    }


    // --------------------------------------------------------
    // Helpers
    // --------------------------------------------------------

    private static func workTitle(
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


    private static func workSort(
        _ lhs: WorkItem,
        _ rhs: WorkItem
    ) -> Bool {
        workTitle(lhs)
            .localizedCaseInsensitiveCompare(
                workTitle(rhs)
            )
            == .orderedAscending
    }


    private static func personSort(
        _ lhs: Entity,
        _ rhs: Entity,
        store: TestudoStore
    ) -> Bool {
        let lhsProfile =
            store.personProfile(
                for:
                    lhs.id
            )

        let rhsProfile =
            store.personProfile(
                for:
                    rhs.id
            )

        let lhsLast =
            lhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsLast =
            rhsProfile?
                .lastName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if
            !lhsLast.isEmpty
            || !rhsLast.isEmpty
        {
            let comparison =
                lhsLast
                    .localizedCaseInsensitiveCompare(
                        rhsLast
                    )

            if comparison != .orderedSame {
                return comparison
                    == .orderedAscending
            }
        }

        let lhsFirst =
            lhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        let rhsFirst =
            rhsProfile?
                .firstName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        if
            !lhsFirst.isEmpty
            || !rhsFirst.isEmpty
        {
            let comparison =
                lhsFirst
                    .localizedCaseInsensitiveCompare(
                        rhsFirst
                    )

            if comparison != .orderedSame {
                return comparison
                    == .orderedAscending
            }
        }

        return lhs.name
            .localizedCaseInsensitiveCompare(
                rhs.name
            )
            == .orderedAscending
    }


    private static func entitySort(
        _ lhs: Entity,
        _ rhs: Entity
    ) -> Bool {
        lhs.name
            .localizedCaseInsensitiveCompare(
                rhs.name
            )
            == .orderedAscending
    }


    private static func entityIcon(
        _ kind: EntityKind
    ) -> String {
        switch kind {
        case .organization:
            return "building.2"

        case .group:
            return "person.3"

        case .person:
            return "person"
        }
    }
}
