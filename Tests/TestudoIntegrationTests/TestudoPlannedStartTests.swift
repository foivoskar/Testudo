import Foundation
import XCTest
@testable import Testudo

@MainActor
private func updatePlannedStart(
    store: TestudoStore,
    id: UUID,
    body: String,
    date: Date?,
    zone: String?,
    deadline: Date? = nil
) -> String? {
    store.updateWorkItemDetails(
        itemID: id,
        title: "Planned Start Test",
        body: body,
        themeID: nil,
        parentWorkItemID: nil,
        status: .todo,
        deadlineAt: deadline,
        reminderAt: nil,
        scheduledAt: nil,
        plannedStartAt: date,
        deadlineTimeZoneID: deadline == nil
            ? nil : "Europe/Paris",
        reminderTimeZoneID: nil,
        plannedStartTimeZoneID: zone
    )
}

final class TestudoPlannedStartTests: XCTestCase {

    func testOrdinaryTaskKeepsSchemaEight() async throws {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "TestudoSchemaEight-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let versions = await MainActor.run { () -> (Int, Int?) in
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            _ = store.createWorkItem(
                themeID: nil,
                parentWorkItemID: nil,
                kind: .task,
                title: "Ordinary Task",
                body: "",
                deadlineAt: nil
            )

            let raw = try? Data(
                contentsOf: store.fileURL
            )

            let object = raw.flatMap {
                try? JSONSerialization.jsonObject(
                    with: $0
                ) as? [String: Any]
            }

            return (
                store.data.schemaVersion,
                object?["schemaVersion"] as? Int
            )
        }

        XCTAssertEqual(versions.0, 8)
        XCTAssertEqual(versions.1, 8)
    }

    func testLegacyTaskDecodesWithoutPlannedStart() throws {
        let task = WorkItem(
            themeID: nil,
            parentWorkItemID: nil,
            kind: .task,
            title: "Legacy Task",
            body: "",
            status: .todo
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let json = try encoder.encode(task)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: json)
                as? [String: Any]
        )

        XCTAssertNil(object["plannedStartAt"])
        XCTAssertNil(object["plannedStartTimeZoneID"])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(
            WorkItem.self,
            from: json
        )

        XCTAssertNil(restored.plannedStartAt)
        XCTAssertNil(restored.plannedStartTimeZoneID)
        XCTAssertEqual(restored.status, .todo)
    }

    func testPlannedStartRoundTripPreservesTimeZone() throws {
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(
                from: "2026-11-02T08:30:00Z"
            )
        )

        var task = WorkItem(
            themeID: nil,
            parentWorkItemID: nil,
            kind: .task,
            title: "Time Zone Test",
            body: "",
            status: .todo
        )

        task.plannedStartAt = date
        task.plannedStartTimeZoneID = "Europe/Paris"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let restored = try decoder.decode(
            WorkItem.self,
            from: encoder.encode(task)
        )

        XCTAssertEqual(restored.plannedStartAt, date)
        XCTAssertEqual(
            restored.plannedStartTimeZoneID,
            "Europe/Paris"
        )
        XCTAssertNil(restored.startedAt)
        XCTAssertEqual(restored.status, .todo)
    }

    func testStorePersistsEditsAndRemoval() async throws {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "TestudoPlannedStart-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let failure = await MainActor.run { () -> String? in
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            guard store.startupBlockedReason == nil else {
                return "Store startup was blocked."
            }

            guard let id = store.createWorkItem(
                themeID: nil,
                parentWorkItemID: nil,
                kind: .task,
                title: "Planned Start Test",
                body: "",
                deadlineAt: nil
            ) else {
                return "Could not create test Task."
            }

            guard let date = ISO8601DateFormatter().date(
                from: "2026-11-02T08:30:00Z"
            ) else {
                return "Could not construct test date."
            }

            if let error = updatePlannedStart(
                store: store,
                id: id,
                body: "",
                date: date,
                zone: "Europe/Paris"
            ) {
                return error
            }

            guard
                store.workItem(id: id)?.plannedStartAt == date,
                store.workItem(id: id)?
                    .plannedStartTimeZoneID == "Europe/Paris",
                store.workItem(id: id)?.status == .todo,
                store.workItem(id: id)?.startedAt == nil
            else {
                return "Initial Planned Start was not stored."
            }

            let initialEvents = store.data.historyEvents
                .filter {
                    $0.workItemID == id
                    && $0.kind == .plannedStartChanged
                }

            guard initialEvents.count == 1 else {
                return "Initial History event was not recorded."
            }

            guard store.data.schemaVersion == 9 else {
                return "Planned Start did not activate schema 9."
            }

            guard
                let storedData = try? Data(
                    contentsOf: store.fileURL
                ),
                let storedObject = try?
                    JSONSerialization.jsonObject(
                        with: storedData
                    ) as? [String: Any],
                storedObject["schemaVersion"] as? Int == 9
            else {
                return "Schema 9 was not written to disk."
            }

            if let error = updatePlannedStart(
                store: store,
                id: id,
                body: "Edited description",
                date: date,
                zone: "Europe/Paris"
            ) {
                return error
            }

            let afterEdit = store.data.historyEvents
                .filter {
                    $0.workItemID == id
                    && $0.kind == .plannedStartChanged
                }

            guard
                afterEdit.count == 1,
                store.workItem(id: id)?
                    .plannedStartAt == date
            else {
                return "Unrelated edit altered Planned Start."
            }

            let reopened = TestudoStore(
                storageDirectoryURL: directory
            )

            guard
                reopened.startupBlockedReason == nil,
                reopened.data.schemaVersion == 9,
                reopened.workItem(id: id)?
                    .plannedStartAt == date,
                reopened.workItem(id: id)?
                    .plannedStartTimeZoneID == "Europe/Paris"
            else {
                return "Planned Start did not survive reload."
            }

            if let error = updatePlannedStart(
                store: reopened,
                id: id,
                body: "Edited description",
                date: nil,
                zone: nil
            ) {
                return error
            }

            let finalEvents = reopened.data.historyEvents
                .filter {
                    $0.workItemID == id
                    && $0.kind == .plannedStartChanged
                }

            guard
                reopened.workItem(id: id)?
                    .plannedStartAt == nil,
                reopened.workItem(id: id)?
                    .plannedStartTimeZoneID == nil,
                reopened.data.schemaVersion == 9,
                finalEvents.count == 2,
                finalEvents.last?.newValue == nil
            else {
                return "Removal or History validation failed."
            }

            return nil
        }

        XCTAssertNil(failure, failure ?? "")
    }

    func testPlannedStartAfterDeadlineIsRejected() async throws {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "TestudoPlannedValidation-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let failure = await MainActor.run { () -> String? in
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            guard let id = store.createWorkItem(
                themeID: nil,
                parentWorkItemID: nil,
                kind: .task,
                title: "Planned Start Test",
                body: "",
                deadlineAt: nil
            ) else {
                return "Could not create test Task."
            }

            let formatter = ISO8601DateFormatter()

            guard
                let start = formatter.date(
                    from: "2026-11-02T08:30:00Z"
                ),
                let deadline = formatter.date(
                    from: "2026-11-01T17:00:00Z"
                )
            else {
                return "Could not construct test dates."
            }

            let error = updatePlannedStart(
                store: store,
                id: id,
                body: "",
                date: start,
                zone: "Europe/Paris",
                deadline: deadline
            )

            guard error ==
                "Planned Start cannot be after Deadline."
            else {
                return "Invalid date order was not rejected."
            }

            guard
                store.workItem(id: id)?
                    .plannedStartAt == nil,
                store.workItem(id: id)?
                    .deadlineAt == nil
            else {
                return "Rejected update modified Task data."
            }

            return nil
        }

        XCTAssertNil(failure, failure ?? "")
    }

    func testTaskAvailabilityRespectsTimeAndHierarchy() async throws {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "TestudoPlannedAvailability-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        let failure = await MainActor.run { () -> String? in
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            guard
                let parentID = store.createWorkItem(
                    themeID: nil,
                    parentWorkItemID: nil,
                    kind: .task,
                    title: "Planned Start Test",
                    body: "",
                    deadlineAt: nil
                ),
                let childID = store.createWorkItem(
                    themeID: nil,
                    parentWorkItemID: parentID,
                    kind: .task,
                    title: "Child Task",
                    body: "",
                    deadlineAt: nil
                ),
                let freeID = store.createWorkItem(
                    themeID: nil,
                    parentWorkItemID: nil,
                    kind: .task,
                    title: "Unscheduled Task",
                    body: "",
                    deadlineAt: nil
                )
            else {
                return "Could not create test Tasks."
            }

            let formatter = ISO8601DateFormatter()

            guard
                let parentStart = formatter.date(
                    from: "2026-11-02T08:30:00Z"
                ),
                let childStart = formatter.date(
                    from: "2026-11-02T10:00:00Z"
                )
            else {
                return "Could not parse Planned Start dates."
            }

            if let error = updatePlannedStart(
                store: store,
                id: parentID,
                body: "",
                date: parentStart,
                zone: "Europe/Paris"
            ) {
                return error
            }

            guard
                let inheritedChild =
                    store.workItem(id: childID),
                store.effectivePlannedStart(
                    for: inheritedChild
                ) == parentStart,
                !store.isTaskAvailableForWork(
                    inheritedChild,
                    at: parentStart.addingTimeInterval(-1)
                ),
                store.isTaskAvailableForWork(
                    inheritedChild,
                    at: parentStart
                )
            else {
                return
                    "Parent-only Planned Start did not propagate to child."
            }

            if let error = store.updateWorkItemDetails(
                itemID: childID,
                title: "Child Task",
                body: "",
                themeID: nil,
                parentWorkItemID: parentID,
                status: .todo,
                deadlineAt: nil,
                reminderAt: nil,
                scheduledAt: nil,
                plannedStartAt: childStart,
                plannedStartTimeZoneID: "Europe/Paris"
            ) {
                return error
            }

            guard
                let parent = store.workItem(id: parentID),
                let child = store.workItem(id: childID),
                let free = store.workItem(id: freeID)
            else {
                return "Could not retrieve test Tasks."
            }

            guard
                !store.isTaskAvailableForWork(
                    parent,
                    at: parentStart.addingTimeInterval(-1)
                ),
                store.isTaskAvailableForWork(
                    parent,
                    at: parentStart
                ),
                !store.isTaskAvailableForWork(
                    child,
                    at: parentStart
                ),
                !store.isTaskAvailableForWork(
                    child,
                    at: childStart.addingTimeInterval(-1)
                ),
                store.isTaskAvailableForWork(
                    child,
                    at: childStart
                ),
                store.isTaskAvailableForWork(
                    free,
                    at: parentStart.addingTimeInterval(-1)
                )
            else {
                return "Exact Planned Start availability failed."
            }

            store.setTaskStatus(
                workItemID: childID,
                status: .inProgress
            )

            guard
                let startedChild = store.workItem(id: childID),
                startedChild.startedAt != nil,
                store.isTaskAvailableForWork(
                    startedChild,
                    at: parentStart.addingTimeInterval(-1)
                )
            else {
                return "Started Task was incorrectly hidden."
            }

            store.setTaskStatus(
                workItemID: parentID,
                status: .completed
            )

            guard
                let completedParent = store.workItem(id: parentID),
                !store.isTaskAvailableForWork(
                    completedParent,
                    at: childStart
                )
            else {
                return "Completed Task remained actionable."
            }

            return nil
        }

        XCTAssertNil(failure, failure ?? "")
    }

}
