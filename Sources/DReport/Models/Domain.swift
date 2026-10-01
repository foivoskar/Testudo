import Foundation

enum WorkItemKind: String, Codable, CaseIterable, Identifiable {
    case task
    case note
    case activity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .task:
            return "Task"
        case .note:
            return "Note"
        case .activity:
            return "Event"
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case inProgress
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}

struct Theme: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var parentThemeID: UUID?

    var name: String
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct WorkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var themeID: UUID?
    var parentWorkItemID: UUID?

    var kind: WorkItemKind

    var title: String?
    var body: String = ""

    var status: TaskStatus?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var scheduledAt: Date?
    var deadlineAt: Date?
    var reminderAt: Date? = nil
    var startedAt: Date?
    var completedAt: Date?
    var loggedAt: Date?

    var createdByUserID: UUID?
    var updatedByUserID: UUID?
}

enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case organization
    case group
    case person

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .organization:
            return "Organization"
        case .group:
            return "Group"
        case .person:
            return "Person"
        }
    }
}

struct Entity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var kind: EntityKind
    var name: String
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct EntityMembership: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var memberEntityID: UUID
    var containerEntityID: UUID

    var isPrimary: Bool = false

    var createdAt: Date = Date()
}

enum WorkRelationshipRole: String, Codable, CaseIterable, Identifiable {
    case forWhom
    case requestedBy
    case with
    case assignedTo
    case relatedTo

    var id: String { rawValue }

    var displayName: String {
        switch self {
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

struct WorkEntityRelationship: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var workItemID: UUID
    var entityID: UUID

    var role: WorkRelationshipRole

    var inheritedByChildren: Bool = true

    var createdAt: Date = Date()
}

enum HistoryEventKind: String, Codable, CaseIterable {
    case created
    case edited
    case statusChanged
    case scheduled
    case started
    case completed
    case activityLogged
    case relationshipAdded
    case relationshipRemoved
    case moved
}

struct HistoryEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var workItemID: UUID
    var kind: HistoryEventKind

    var timestamp: Date = Date()

    var text: String?
    var previousValue: String?
    var newValue: String?

    var actorUserID: UUID?
}
