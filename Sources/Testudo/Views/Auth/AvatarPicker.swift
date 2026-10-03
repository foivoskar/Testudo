import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AvatarPicker: View {
    @Binding
    var avatarData: Data?

    @State
    private var showingImporter = false

    @State
    private var errorMessage: String?

    var body: some View {
        HStack(spacing: 14) {
            avatarPreview

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Button(
                    avatarData == nil
                    ? "Choose Photo…"
                    : "Change Photo…"
                ) {
                    showingImporter = true
                }

                if avatarData != nil {
                    Button("Remove Photo") {
                        avatarData = nil
                    }
                    .buttonStyle(.link)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .fileImporter(
            isPresented:
                $showingImporter,
            allowedContentTypes: [
                .image
            ],
            allowsMultipleSelection:
                false
        ) { result in
            switch result {
            case .success(let urls):
                guard
                    let url =
                        urls.first
                else {
                    return
                }

                let accessing =
                    url.startAccessingSecurityScopedResource()

                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let data =
                        try Data(
                            contentsOf: url
                        )

                    guard
                        data.count
                            <= 5_000_000,
                        NSImage(
                            data: data
                        ) != nil
                    else {
                        errorMessage =
                            "Choose a valid image smaller than 5 MB."
                        return
                    }

                    avatarData = data
                    errorMessage = nil
                } catch {
                    errorMessage =
                        "The image could not be read."
                }

            case .failure:
                errorMessage =
                    "The image could not be selected."
            }
        }
    }

    @ViewBuilder
    private var avatarPreview:
        some View
    {
        if
            let avatarData,
            let image =
                NSImage(
                    data:
                        avatarData
                )
        {
            Image(
                nsImage: image
            )
            .resizable()
            .scaledToFill()
            .frame(
                width: 54,
                height: 54
            )
            .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(
                        Color.secondary
                            .opacity(0.12)
                    )

                Image(
                    systemName:
                        "person.fill"
                )
                .font(.title2)
                .foregroundStyle(
                    .secondary
                )
            }
            .frame(
                width: 54,
                height: 54
            )
        }
    }
}
