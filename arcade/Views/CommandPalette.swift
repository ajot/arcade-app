import SwiftUI

struct CommandPalette: View {
    @Bindable var state: AppState
    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @State private var step: PaletteStep = .endpoints
    @State private var selectedDefinition: Definition?
    @State private var appeared = false
    @FocusState private var isSearchFocused: Bool

    enum PaletteStep {
        case endpoints
        case models
    }

    // Flattened list item for stable identities
    private enum PaletteItem: Identifiable {
        case header(OutputType)
        case endpoint(Definition, Int) // definition + flat index

        var id: String {
            switch self {
            case .header(let type): return "header-\(type.rawValue)"
            case .endpoint(let def, _): return def.id
            }
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Panel
            VStack(spacing: 0) {
                // Breadcrumb (model step only)
                if step == .models, let def = selectedDefinition {
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                step = .endpoints
                                selectedDefinition = nil
                                searchText = ""
                                highlightedIndex = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isSearchFocused = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10))
                                Text(def.name)
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textMuted)
                    TextField(
                        step == .endpoints ? "Search endpoints..." : "Search models...",
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) {
                        highlightedIndex = 0
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .background(Color.border700)

                // Results
                ScrollView {
                    VStack(spacing: 0) {
                        switch step {
                        case .endpoints:
                            endpointList
                        case .models:
                            modelList
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)

                // Footer hints
                Divider()
                    .background(Color.border700)

                HStack(spacing: 16) {
                    hintLabel(key: "\u{21B5}", text: "Select")
                    if step == .endpoints && state.mode == .play {
                        hintLabel(key: "\u{21E7}\u{21B5}", text: "Compare")
                    }
                    hintLabel(key: "Esc", text: "Close")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.bg900)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.border700, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            .frame(width: 520)
            .scaleEffect(appeared ? 1 : 0.98)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
            SoundService.paletteOpen()
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
            if step == .models {
                withAnimation(.easeOut(duration: 0.15)) {
                    step = .endpoints
                    selectedDefinition = nil
                    searchText = ""
                    highlightedIndex = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            } else {
                dismiss()
            }
            return .handled
        }
    }

    // MARK: - Endpoint List (flattened for stable identities)

    private var flatEndpointItems: [PaletteItem] {
        let grouped = filteredEndpointsByType
        let outputOrder: [OutputType] = [.text, .image, .audio, .video]
        var items: [PaletteItem] = []
        var flatIdx = 0

        for type in outputOrder {
            guard let defs = grouped[type], !defs.isEmpty else { continue }
            items.append(.header(type))
            for def in defs {
                items.append(.endpoint(def, flatIdx))
                flatIdx += 1
            }
        }
        return items
    }

    @ViewBuilder
    private var endpointList: some View {
        let items = flatEndpointItems

        ForEach(items) { item in
            switch item {
            case .header(let outputType):
                Text(outputType.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

            case .endpoint(let def, let flatIndex):
                let hasKey = state.keyStatus[def.provider] != .noKey

                Button {
                    selectEndpoint(def)
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: def.outputType.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                            .frame(width: 20)
                            .padding(.trailing, 8)

                        Text(def.providerDisplayName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                            .padding(.trailing, 6)

                        Text(def.name)
                            .font(.system(size: 13))
                            .foregroundStyle(hasKey ? Color.textPrimary : Color.textMuted)

                        Spacer()

                        if def.modelCount > 0 {
                            Text("\(def.modelCount) models")
                                .font(.brandSmall)
                                .foregroundStyle(Color.textMuted)
                        }

                        if !hasKey {
                            Text("no key")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accent)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        flatIndex == highlightedIndex
                            ? Color.accentSubtle
                            : Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hasKey ? 1.0 : 0.4)
            }
        }
    }

    // MARK: - Model List

    @ViewBuilder
    private var modelList: some View {
        let models = filteredModels

        ForEach(Array(models.enumerated()), id: \.element) { index, model in
            let isDefault = model == selectedDefinition?.defaultModel

            Button {
                selectModel(model)
            } label: {
                HStack {
                    Text(model)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)

                    if isDefault {
                        Text("default")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.bg800)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    index == highlightedIndex
                        ? Color.accentSubtle
                        : Color.clear
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filtering

    private var filteredEndpointsByType: [OutputType: [Definition]] {
        let all = state.definitionLoader.definitionsByOutputType
        if searchText.isEmpty { return all }
        let query = searchText.lowercased()
        var result: [OutputType: [Definition]] = [:]
        for (type, defs) in all {
            let filtered = defs.filter {
                $0.name.lowercased().contains(query) ||
                $0.provider.lowercased().contains(query) ||
                $0.providerDisplayName.lowercased().contains(query)
            }
            if !filtered.isEmpty {
                result[type] = filtered
            }
        }
        return result
    }

    private var totalFilteredCount: Int {
        let grouped = filteredEndpointsByType
        let outputOrder: [OutputType] = [.text, .image, .audio, .video]
        var count = 0
        for type in outputOrder {
            count += grouped[type]?.count ?? 0
        }
        return count
    }

    private var filteredModels: [String] {
        guard let def = selectedDefinition, let options = def.modelParam?.options else { return [] }
        var sorted = options
        if let defaultModel = def.defaultModel,
           let idx = sorted.firstIndex(of: defaultModel) {
            sorted.remove(at: idx)
            sorted.insert(defaultModel, at: 0)
        }
        if searchText.isEmpty { return sorted }
        let query = searchText.lowercased()
        return sorted.filter { $0.lowercased().contains(query) }
    }

    // MARK: - Navigation

    private func moveHighlight(_ delta: Int) {
        let count = step == .endpoints ? totalFilteredCount : filteredModels.count
        guard count > 0 else { return }
        highlightedIndex = (highlightedIndex + delta + count) % count
    }

    private func selectHighlighted() {
        switch step {
        case .endpoints:
            let grouped = filteredEndpointsByType
            let outputOrder: [OutputType] = [.text, .image, .audio, .video]
            var idx = 0
            for type in outputOrder {
                guard let defs = grouped[type] else { continue }
                for def in defs {
                    if idx == highlightedIndex {
                        selectEndpoint(def)
                        return
                    }
                    idx += 1
                }
            }
        case .models:
            let models = filteredModels
            if highlightedIndex < models.count {
                selectModel(models[highlightedIndex])
            }
        }
    }

    private func selectEndpoint(_ definition: Definition) {
        if definition.modelCount > 1 {
            selectedDefinition = definition
            searchText = ""
            highlightedIndex = 0
            withAnimation(.easeOut(duration: 0.15)) {
                step = .models
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
            SoundService.select()
        } else {
            state.selectEndpoint(definition)
            SoundService.select()
        }
    }

    private func selectModel(_ model: String) {
        if let def = selectedDefinition {
            state.selectEndpoint(def, model: model)
            SoundService.select()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.12)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            state.showCommandPalette = false
        }
    }

    // MARK: - Hint Label

    private func hintLabel(key: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.bg800)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Color.textMuted)
        }
    }
}
