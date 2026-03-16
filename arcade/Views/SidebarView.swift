import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState
    @State private var searchText = ""
    @State private var hoveredDefinition: String?

    private let outputTypeOrder: [OutputType] = [.text, .image, .audio, .video]

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { state.currentDefinition?.id },
                set: { id in
                    if let id, let def = state.definitionLoader.sortedDefinitions.first(where: { $0.id == id }) {
                        state.selectEndpoint(def)
                    }
                }
            )) {
                ForEach(outputTypeOrder, id: \.self) { type in
                    let defs = filteredDefinitions(for: type)
                    if !defs.isEmpty {
                        Section(type.rawValue.capitalized) {
                            ForEach(defs) { definition in
                                sidebarRow(definition)
                                    .tag(definition.id)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search endpoints")
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 12) {
                Button {
                    state.definitionLoader.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reload Definitions")

                Spacer()

                Button {
                    state.definitionLoader.showDefinitionsFolder()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show Definitions Folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.definitionLoader.reload()
        }
    }

    // MARK: - Row

    private func sidebarRow(_ definition: Definition) -> some View {
        let keyStatus = state.keyStatus[definition.provider] ?? .noKey

        return HStack(spacing: 8) {
            ProviderIconView(
                provider: definition.provider,
                displayName: definition.providerDisplayName,
                iconUrl: definition.providerIconUrl,
                iconService: state.iconService
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(definition.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(definition.providerDisplayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if definition.modelCount > 1 {
                        Text("· \(definition.modelCount) models")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Circle()
                .fill(keyStatus.color)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Filtering & Sorting

    private func filteredDefinitions(for type: OutputType) -> [Definition] {
        var all = state.definitionLoader.definitionsByOutputType[type] ?? []
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            all = all.filter {
                $0.name.lowercased().contains(query) ||
                $0.providerDisplayName.lowercased().contains(query)
            }
        }
        return all.sorted { a, b in
            let aPriority = keyPriority(for: a.provider)
            let bPriority = keyPriority(for: b.provider)
            if aPriority != bPriority { return aPriority < bPriority }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Sort priority: valid keys first, then keys present but not validated, then no key.
    private func keyPriority(for provider: String) -> Int {
        switch state.keyStatus[provider] ?? .noKey {
        case .valid: return 0
        case .checking, .unknown: return 1
        case .invalid: return 2
        case .noKey: return 3
        }
    }
}
