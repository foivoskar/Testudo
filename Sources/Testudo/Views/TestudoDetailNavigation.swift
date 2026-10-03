import SwiftUI


// ============================================================
// MARK: - Detail-pane navigation
//
// Right-pane references use this action instead of creating
// their own navigation state.
//
// ContentView translates these destinations into the existing
// Testudo browser navigation/history system.
// ============================================================

enum TestudoDetailDestination:
    Equatable,
    Sendable
{
    case work(UUID)
    case theme(UUID)
    case organization(UUID)
    case group(UUID)
    case person(UUID)
}


struct TestudoDetailNavigationAction:
    @unchecked Sendable
{
    private let handler:
        (TestudoDetailDestination) -> Void


    init(
        _ handler:
            @escaping (TestudoDetailDestination) -> Void
    ) {
        self.handler =
            handler
    }


    func callAsFunction(
        _ destination:
            TestudoDetailDestination
    ) {
        handler(
            destination
        )
    }


    func open(
        _ entity:
            Entity
    ) {
        switch entity.kind {

        case .organization:
            handler(
                .organization(
                    entity.id
                )
            )

        case .group:
            handler(
                .group(
                    entity.id
                )
            )

        case .person:
            handler(
                .person(
                    entity.id
                )
            )
        }
    }
}


private struct TestudoDetailNavigationKey:
    EnvironmentKey
{
    static let defaultValue =
        TestudoDetailNavigationAction {
            _ in
        }
}


extension EnvironmentValues {

    var testudoDetailNavigation:
        TestudoDetailNavigationAction
    {
        get {
            self[
                TestudoDetailNavigationKey.self
            ]
        }

        set {
            self[
                TestudoDetailNavigationKey.self
            ] =
                newValue
        }
    }
}


// ============================================================
// MARK: - Shared clickable entity names
// ============================================================

struct TestudoEntityLinks:
    View
{
    @Environment(
        \.testudoDetailNavigation
    )
    private var detailNavigation


    let entities:
        [Entity]

    var font:
        Font = .caption

    var color:
        Color = .secondary


    var body: some View {
        ScrollView(
            .horizontal,
            showsIndicators:
                false
        ) {
            HStack(
                spacing:
                    5
            ) {
                ForEach(
                    entities
                ) { entity in

                    if
                        entity.id
                            != entities
                                .first?
                                .id
                    {
                        Text("·")
                            .foregroundStyle(
                                .tertiary
                            )
                    }


                    Button {
                        detailNavigation
                            .open(
                                entity
                            )
                    } label: {
                        Text(
                            entity.name
                        )
                        .foregroundStyle(
                            color
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .help(
                        "Open \(entity.name)"
                    )
                }
            }
        }
        .font(
            font
        )
    }
}
