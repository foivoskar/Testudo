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
    case closed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"

        case .closed:
            return "Closed"
        }
    }
}

enum StructureStatus:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case active
    case onHold
    case archived

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .active:
            return "Active"

        case .onHold:
            return "On Hold"

        case .archived:
            return "Archived"
        }
    }
}


enum StructurePriority:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case low
    case normal
    case high
    case critical

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .low:
            return "Low"

        case .normal:
            return "Normal"

        case .high:
            return "High"

        case .critical:
            return "Critical"
        }
    }
}


struct Theme: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var parentThemeID: UUID?

    var name: String
    var notes: String = ""

    var summary: String? = nil
    var code: String? = nil

    var status: StructureStatus? = nil
    var priority: StructurePriority? = nil

    var ownerEntityID: UUID? = nil

    var startDate: Date? = nil
    var targetDate: Date? = nil

    var tags: String? = nil
    var url: String? = nil

    var symbolName: String? = nil

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct WorkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    var themeID: UUID?

    // Multiple Theme membership.
    //
    // nil:
    //   legacy WorkItem — use themeID as fallback.
    //
    // []:
    //   explicitly assigned to no Themes.
    //
    // [UUID, ...]:
    //   explicit multi-Theme membership.
    var themeIDs: [UUID]? = nil
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

    // IANA time-zone identifiers describing the zone
    // in which each timestamp was originally entered
    // or automatically recorded.
    //
    // Date itself remains an absolute instant.
    var createdTimeZoneID: String? = nil
    var updatedTimeZoneID: String? = nil

    var scheduledTimeZoneID: String? = nil
    var deadlineTimeZoneID: String? = nil
    var reminderTimeZoneID: String? = nil

    var startedTimeZoneID: String? = nil
    var completedTimeZoneID: String? = nil
    var loggedTimeZoneID: String? = nil
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

    var shortName: String? = nil
    var code: String? = nil

    var status: StructureStatus? = nil
    var priority: StructurePriority? = nil

    var ownerEntityID: UUID? = nil

    var startDate: Date? = nil
    var targetDate: Date? = nil

    var website: String? = nil
    var email: String? = nil
    var phone: String? = nil

    var address: String? = nil
    var city: String? = nil
    var postalCode: String? = nil
    var country: String? = nil

    var tags: String? = nil
    var symbolName: String? = nil

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


struct ThemeEntityRelationship:
    Identifiable,
    Codable,
    Hashable
{
    var id:
        UUID = UUID()

    var themeID:
        UUID

    var entityID:
        UUID

    var createdAt:
        Date = Date()
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

    // Zone where the history action happened.
    var timeZoneID: String? = nil

    // Optional source zone of a date/time value
    // described by this history event.
    var valueTimeZoneID: String? = nil
}
