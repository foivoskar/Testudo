import Foundation
import XCTest
@testable import Testudo

final class TestudoArchivedTaskVisibilityTests: XCTestCase {

    func testArchivedSubtreeIsExcludedFromActiveQueries() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "TestudoArchiveVisibility-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        await MainActor.run {
            let store = TestudoStore(
                storageDirectoryURL: directory
            )

            @MainActor
            func create(
                _ title: String,
                kind: WorkItemKind = .task,
                parent: UUID? = nil
            ) -> UUID? {
                store.createWorkItem(
                    themeID: nil,
                    parentWorkItemID: parent,
                    kind: kind,
                    title: title,
                    body: "",
                    deadlineAt: nil
                )
            }

            guard
                let root = create("Archive root"),
                let todo = create("Archived To Do", parent: root),
                let progress = create("Archived In Progress", parent: root),
                let completed = create("Archived Completed", parent: root),
                let nested = create("Deep descendant", parent: todo),
                let note = create(
                    "Archived Note",
                    kind: .note,
                    parent: root
                ),
                let openTask = create("Active Task")
            else {
                XCTFail("Could not create test data")
                return
            }

            store.setTaskStatus(
                workItemID: progress,
                status: .inProgress
            )

            store.setTaskStatus(
                workItemID: completed,
                status: .completed
            )

            store.setTaskStatus(
                workItemID: root,
                status: .completed
            )

            XCTAssertNil(
                store.closeTopLevelTask(workItemID: root)
            )

            let archivedIDs: Set<UUID> = [
                root, todo, progress, completed, nested
            ]

            for status in [
                TaskStatus.todo,
                .inProgress,
                .completed,
                .discontinued
            ] {
                let visible = Set(
                    store.tasks(with: status).map(\.id)
                )

                XCTAssertTrue(
                    visible.isDisjoint(with: archivedIDs)
                )
            }

            XCTAssertTrue(
                store.tasks(with: .todo).contains {
                    $0.id == openTask
                }
            )

            let availableParents = Set(
                HierarchySelectionData.taskNodes(
                    store: store,
                    includeArchivedTasks: false
                ).compactMap(\.selectionID)
            )

            XCTAssertTrue(
                availableParents.isDisjoint(with: archivedIDs)
            )
            XCTAssertTrue(
                availableParents.contains(openTask)
            )

            XCTAssertTrue(
                HierarchySelectionData.taskNodes(
                    store: store
                ).contains {
                    $0.selectionID == root
                }
            )

            XCTAssertTrue(
                store.archivedRootTasks().contains {
                    $0.id == root
                }
            )

            XCTAssertFalse(
                store.activeWorkItems.contains {
                    $0.id == note
                }
            )

            XCTAssertEqual(
                store.workItem(id: note)?.parentWorkItemID,
                root
            )

            XCTAssertNil(
                store.reopenTopLevelTask(workItemID: root)
            )

            XCTAssertTrue(
                store.tasks(with: .todo).contains {
                    $0.id == nested
                }
            )

            XCTAssertTrue(
                store.tasks(with: .inProgress).contains {
                    $0.id == progress
                }
            )

            XCTAssertTrue(
                store.tasks(with: .completed).contains {
                    $0.id == root
                }
            )

            XCTAssertTrue(
                HierarchySelectionData.taskNodes(
                    store: store,
                    includeArchivedTasks: false
                ).contains {
                    $0.selectionID == root
                }
            )

            XCTAssertTrue(
                store.activeWorkItems.contains {
                    $0.id == note
                }
            )

            XCTAssertEqual(
                store.workItem(id: root)?.status,
                .completed
            )
        }
    }
}
