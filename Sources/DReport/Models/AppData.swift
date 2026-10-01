import Foundation

struct DReportData: Codable {
    var schemaVersion: Int = 1

    var themes: [Theme] = []
    var workItems: [WorkItem] = []

    var entities: [Entity] = []
    var memberships: [EntityMembership] = []

    var workEntityRelationships: [WorkEntityRelationship] = []
    var historyEvents: [HistoryEvent] = []
}
