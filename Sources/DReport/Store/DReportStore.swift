import Foundation
import Combine

@MainActor
final class DReportStore: ObservableObject {
    @Published private(set) var data: DReportData

    let fileURL: URL

    init() {
        let fileManager = FileManager.default

        let baseDirectory =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")

        let directory =
            baseDirectory
                .appendingPathComponent(
                    "DReport",
                    isDirectory: true
                )

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            print(
                "DReport: could not create storage directory:",
                error
            )
        }

        fileURL =
            directory
                .appendingPathComponent("DReportData.json")

        if
            let storedData = try? Data(contentsOf: fileURL),
            let decoded = Self.decode(storedData)
        {
            data = decoded
        } else {
            data = DReportData()
        }
    }

    private static func decode(
        _ rawData: Data
    ) -> DReportData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(
                DReportData.self,
                from: rawData
            )
        } catch {
            print(
                "DReport: could not decode stored data:",
                error
            )
            return nil
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let encoded =
                try encoder.encode(data)

            try encoded.write(
                to: fileURL,
                options: .atomic
            )
        } catch {
            print(
                "DReport: could not save data:",
                error
            )
        }
    }

    func createTheme(
        name: String,
        parentThemeID: UUID?
    ) {
        let cleaned =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return
        }

        let theme =
            Theme(
                parentThemeID: parentThemeID,
                name: cleaned
            )

        data.themes.append(theme)
        save()
    }

    func deleteTheme(
        id: UUID
    ) {
        let descendantIDs =
            themeDescendantIDs(of: id)

        let allIDs =
            Set(descendantIDs + [id])

        data.themes.removeAll {
            allIDs.contains($0.id)
        }

        data.workItems.removeAll {
            guard let themeID = $0.themeID else {
                return false
            }

            return allIDs.contains(themeID)
        }

        save()
    }

    func createEntity(
        kind: EntityKind,
        name: String,
        initialContainerID: UUID?
    ) {
        let cleaned =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleaned.isEmpty else {
            return
        }

        let entity =
            Entity(
                kind: kind,
                name: cleaned
            )

        data.entities.append(entity)

        if let initialContainerID {
            let membership =
                EntityMembership(
                    memberEntityID: entity.id,
                    containerEntityID: initialContainerID,
                    isPrimary: true
                )

            data.memberships.append(membership)
        }

        save()
    }

    func addMembership(
        memberID: UUID,
        containerID: UUID
    ) {
        guard memberID != containerID else {
            return
        }

        let exists =
            data.memberships.contains {
                $0.memberEntityID == memberID
                && $0.containerEntityID == containerID
            }

        guard !exists else {
            return
        }

        data.memberships.append(
            EntityMembership(
                memberEntityID: memberID,
                containerEntityID: containerID
            )
        )

        save()
    }

    func deleteEntity(
        id: UUID
    ) {
        data.entities.removeAll {
            $0.id == id
        }

        data.memberships.removeAll {
            $0.memberEntityID == id
            || $0.containerEntityID == id
        }

        data.workEntityRelationships.removeAll {
            $0.entityID == id
        }

        save()
    }

    func memberships(
        for entityID: UUID
    ) -> [EntityMembership] {
        data.memberships.filter {
            $0.memberEntityID == entityID
        }
    }

    func containers(
        for entityID: UUID
    ) -> [Entity] {
        let containerIDs =
            Set(
                memberships(for: entityID)
                    .map(\.containerEntityID)
            )

        return data.entities
            .filter {
                containerIDs.contains($0.id)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    func entity(
        id: UUID
    ) -> Entity? {
        data.entities.first {
            $0.id == id
        }
    }

    func entities(
        of kind: EntityKind
    ) -> [Entity] {
        data.entities
            .filter {
                $0.kind == kind
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare(
                    $1.name
                ) == .orderedAscending
            }
    }

    func possibleContainers(
        for kind: EntityKind
    ) -> [Entity] {
        switch kind {
        case .organization:
            return data.entities
                .filter {
                    $0.kind == .organization
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare(
                        $1.name
                    ) == .orderedAscending
                }

        case .group:
            return data.entities
                .filter {
                    $0.kind == .organization
                    || $0.kind == .group
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare(
                        $1.name
                    ) == .orderedAscending
                }

        case .person:
            return data.entities
                .filter {
                    $0.kind == .organization
                    || $0.kind == .group
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare(
                        $1.name
                    ) == .orderedAscending
                }
        }
    }

    func themeDescendantIDs(
        of parentID: UUID
    ) -> [UUID] {
        let directChildren =
            data.themes
                .filter {
                    $0.parentThemeID == parentID
                }

        var result =
            directChildren.map(\.id)

        for child in directChildren {
            result.append(
                contentsOf:
                    themeDescendantIDs(
                        of: child.id
                    )
            )
        }

        return result
    }
}
