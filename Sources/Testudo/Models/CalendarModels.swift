import Foundation

enum CalendarProvider:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case local
    case google

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .local:
            return "Local"
        case .google:
            return "Google Calendar"
        }
    }
}


struct CalendarAccount:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var provider:
        CalendarProvider

    var displayName:
        String

    var email:
        String? = nil

    var providerAccountID:
        String? = nil

    // Only a Keychain lookup reference.
    // OAuth tokens themselves must not live in TestudoData.json.
    var credentialKeychainAccount:
        String? = nil

    var syncEnabled:
        Bool = true

    var lastSyncAt:
        Date? = nil

    var createdAt:
        Date = Date()

    var updatedAt:
        Date = Date()
}


enum CalendarSourceKind:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case local
    case iCalSubscription
    case appleEventKit

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .local:
            return "Testudo"

        case .iCalSubscription:
            return "iCal Subscription"

        case .appleEventKit:
            return "Apple Calendar / iCloud"
        }
    }

    var systemImage: String {
        switch self {
        case .local:
            return "calendar"

        case .iCalSubscription:
            return "link"

        case .appleEventKit:
            return "apple.logo"
        }
    }
}


struct TestudoCalendar:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var accountID:
        UUID? = nil

    var externalID:
        String? = nil

    var sourceKind:
        CalendarSourceKind? = nil

    /*
     The actual Secret iCal URL is never persisted here.
     This value is only the Keychain lookup key.
    */
    var secretURLKeychainAccount:
        String? = nil

    var lastSyncError:
        String? = nil

    var name:
        String

    var isEnabled:
        Bool = true

    var isReadOnly:
        Bool = false

    var colorHex:
        String? = nil

    var timeZoneID:
        String? = nil

    var syncToken:
        String? = nil

    var lastSyncAt:
        Date? = nil

    var createdAt:
        Date = Date()

    var updatedAt:
        Date = Date()
}


enum CalendarEventStatus:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case confirmed
    case tentative
    case cancelled

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .confirmed:
            return "Confirmed"
        case .tentative:
            return "Tentative"
        case .cancelled:
            return "Cancelled"
        }
    }
}


enum CalendarSyncState:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case localOnly
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
    case conflict

    var id: String {
        rawValue
    }
}


struct CalendarEvent:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var calendarID:
        UUID? = nil

    var externalID:
        String? = nil

    var iCalUID:
        String? = nil

    var externalETag:
        String? = nil

    var externalURL:
        String? = nil

    var title:
        String

    var notes:
        String = ""

    var location:
        String? = nil

    var startAt:
        Date

    var endAt:
        Date

    var isAllDay:
        Bool = false

    var startTimeZoneID:
        String? = nil

    var endTimeZoneID:
        String? = nil

    var status:
        CalendarEventStatus = .confirmed

    var recurrenceRules:
        [String] = []

    var recurringEventExternalID:
        String? = nil

    var originalStartAt:
        Date? = nil

    var organizerName:
        String? = nil

    var organizerEmail:
        String? = nil

    var attendeeEmails:
        [String] = []

    var conferenceURL:
        String? = nil

    var syncState:
        CalendarSyncState = .localOnly

    var externalCreatedAt:
        Date? = nil

    var externalUpdatedAt:
        Date? = nil

    var lastSyncedAt:
        Date? = nil

    var createdAt:
        Date = Date()

    var updatedAt:
        Date = Date()
}


struct CalendarEventWorkLink:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var calendarEventID:
        UUID

    var workItemID:
        UUID

    var createdAt:
        Date = Date()
}


struct CalendarEventThemeLink:
    Identifiable,
    Codable,
    Hashable
{
    var id: UUID = UUID()

    var calendarEventID:
        UUID

    var themeID:
        UUID

    var createdAt:
        Date = Date()
}
