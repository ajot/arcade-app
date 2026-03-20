import SwiftUI

struct ModelPicker: View {
    @Bindable var state: AppState
    let onSelect: (Definition, String) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @FocusState private var isSearchFocused: Bool

    // MARK: - Flattened Items

    private enum PickerItem: Identifiable {
        case provider(Definition)          // group header keyed by definition id
        case model(Definition, String, Int) // definition + model name + flat selectable index

        var id: String {
            switch self {
            case .provider(let def): return "provider-\(def.id)"
            case .model(let def, let model, _): return "\(def.id)-\(model)"
            }
        }
    }

    private var flatItems: [PickerItem] {
        let query = searchText.lowercased()
        var items: [PickerItem] = []
        var flatIdx = 0

        for definition in state.definitionLoader.sortedDefinitions {
            guard let models = definition.modelParam?.options, !models.isEmpty else { continue }

            let filtered: [String]
            if query.isEmpty {
                filtered = models
            } else {
                filtered = models.filter {
                    $0.lowercased().contains(query) ||
                    definition.providerDisplayName.lowercased().contains(query) ||
                    definition.provider.lowercased().contains(query)
                }
            }
            guard !filtered.isEmpty else { continue }

            items.append(.provider(definition))
            for model in filtered {
                items.append(.model(definition, model, flatIdx))
                flatIdx += 1
            }
        }
        return items
    }

    private var selectableCount: Int {
        flatItems.reduce(0) { count, item in
            if case .model = item { return count + 1 }
            return count
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(.secondary)
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(.primary)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) {
                        highlightedIndex = 0
                    }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            Divider()
                .background(.separator)

            // Model list
            ScrollView {
                VStack(spacing: 0) {
                    let items = flatItems
                    if items.isEmpty {
                        Text("No matching models")
                            .font(.system(size: DS.Font.body))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxl)
                    } else {
                        ForEach(items) { item in
                            switch item {
                            case .provider(let definition):
                                providerHeader(definition)
                            case .model(let definition, let model, let flatIndex):
                                modelRow(definition: definition, model: model, flatIndex: flatIndex)
                            }
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .frame(maxHeight: 300)

            // Footer hints
            Divider()
                .background(.separator)

            HStack(spacing: DS.Spacing.lg) {
                hintLabel(key: "\u{2191}\u{2193}", text: "Navigate")
                hintLabel(key: "\u{21B5}", text: "Select")
                hintLabel(key: "Esc", text: "Close")
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .frame(width: 300)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onKeyPress(.upArrow) {
            moveHighlight(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveHighlight(1)
            return .handled
        }
        .onKeyPress(.return) {
            selectHighlighted()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    // MARK: - Provider Header

    @ViewBuilder
    private func providerHeader(_ definition: Definition) -> some View {
        let hasKey = hasValidKey(for: definition)

        HStack(spacing: DS.Spacing.sm) {
            ProviderIconView(
                provider: definition.provider,
                displayName: definition.providerDisplayName,
                iconUrl: definition.providerIconUrl,
                iconService: state.iconService,
                size: 16
            )

            Text(definition.providerDisplayName)
                .font(.system(size: DS.Font.secondary, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if !hasKey {
                Text("no key")
                    .font(.system(size: DS.Font.caption))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
        .opacity(hasKey ? 1.0 : 0.35)
    }

    // MARK: - Model Row

    @ViewBuilder
    private func modelRow(definition: Definition, model: String, flatIndex: Int) -> some View {
        let hasKey = hasValidKey(for: definition)
        let isSelected = state.currentDefinition?.id == definition.id && state.currentModel == model

        Button {
            if hasKey {
                onSelect(definition, model)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(model)
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(hasKey ? .primary : .tertiary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: DS.Font.secondary, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.leading, DS.Spacing.xl) // indent under provider
            .padding(.vertical, 6)
            .background(
                flatIndex == highlightedIndex
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasKey)
        .opacity(hasKey ? 1.0 : 0.35)
    }

    // MARK: - Helpers

    private func hasValidKey(for definition: Definition) -> Bool {
        let status = state.keyStatus[definition.provider]
        return status != .noKey && status != .invalid
    }

    private func moveHighlight(_ delta: Int) {
        let count = selectableCount
        guard count > 0 else { return }
        highlightedIndex = (highlightedIndex + delta + count) % count
    }

    private func selectHighlighted() {
        for item in flatItems {
            if case .model(let def, let model, let idx) = item, idx == highlightedIndex {
                if hasValidKey(for: def) {
                    onSelect(def, model)
                }
                return
            }
        }
    }

    private func hintLabel(key: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(key)
                .font(.system(size: DS.Font.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, 1)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            Text(text)
                .font(.system(size: DS.Font.caption))
                .foregroundStyle(.secondary)
        }
    }
}
