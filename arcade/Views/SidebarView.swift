import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState
    @State private var searchText = ""
    @State private var hoveredDefinition: String?

    private let outputTypeOrder: [OutputType] = [.text, .image, .audio, .video]

    var body: some View {
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
    }

    // MARK: - Row

    private func sidebarRow(_ definition: Definition) -> some View {
        let keyStatus = state.keyStatus[definition.provider] ?? .noKey

        return HStack(spacing: 8) {
            Image(systemName: definition.outputType.iconName)
                .font(.system(size: 11))
                .foregroundStyle(Color.accent)
                .frame(width: 16)

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

            if keyStatus == .noKey {
                Text("no key")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accent.opacity(0.7))
            } else {
                Circle()
                    .fill(keyStatus == .valid ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Filtering

    private func filteredDefinitions(for type: OutputType) -> [Definition] {
        let all = state.definitionLoader.definitionsByOutputType[type] ?? []
        if searchText.isEmpty { return all }
        let query = searchText.lowercased()
        return all.filter {
            $0.name.lowercased().contains(query) ||
            $0.providerDisplayName.lowercased().contains(query)
        }
    }
}
