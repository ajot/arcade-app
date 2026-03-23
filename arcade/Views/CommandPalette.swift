import SwiftUI

struct CommandPalette: View {
    @Bindable var state: AppState
    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @State private var step: PaletteStep = .endpoints
    @State private var selectedDefinition: Definition?
    @State private var appeared = false
    @State private var isContextModelMode = false
    @FocusState private var isSearchFocused: Bool

    @State private var hoveredBookmarkId: UUID?

    enum PaletteStep {
        case endpoints
        case models
        case bookmarks
    }

    // Flattened list item for stable identities
    private enum PaletteItem: Identifiable {
        case header(OutputType)
        case providerHeader(String) // provider display name
        case endpoint(Definition, Int) // definition + flat index
        case model(Definition, String, Int) // definition + model name + flat index

        var id: String {
            switch self {
            case .header(let type): return "header-\(type.rawValue)"
            case .providerHeader(let name): return "provider-\(name)"
            case .endpoint(let def, _): return def.id
            case .model(let def, let model, _): return "\(def.id)-model-\(model)"
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
                // Breadcrumb (model step only, not in context mode)
                if !isContextModelMode, step == .models, let def = selectedDefinition {
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
                                    .font(.system(size: DS.Font.caption))
                                Text(def.name)
                                    .font(.system(size: DS.Font.secondary))
                            }
                            .foregroundStyle(.tertiary)
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
                        .font(.system(size: DS.Font.body))
                        .foregroundStyle(.secondary)
                    TextField(
                        searchPlaceholder,
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(.primary)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) {
                        highlightedIndex = 0
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .background(.separator)

                // Results
                ScrollView {
                    VStack(spacing: 0) {
                        if isContextModelMode {
                            contextModelList
                        } else {
                            switch step {
                            case .endpoints:
                                endpointList
                            case .models:
                                modelList
                            case .bookmarks:
                                bookmarkList
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)

                // Footer hints
                Divider()
                    .background(.separator)

                HStack(spacing: 16) {
                    if step != .models && !isContextModelMode {
                        // Tab toggle pill
                        HStack(spacing: 0) {
                            tabPill("Endpoints", isActive: step == .endpoints) {
                                switchToEndpoints()
                            }
                            tabPill("Bookmarks", isActive: step == .bookmarks) {
                                switchToBookmarks()
                            }
                        }
                        .background(.quinary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
                        )

                        hintLabel(key: "Tab", text: "Switch")
                    }

                    hintLabel(key: "\u{21B5}", text: "Select")
                    if step == .bookmarks {
                        hintLabel(key: "\u{232B}", text: "Delete")
                    }
                    hintLabel(key: "Esc", text: "Close")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            .frame(width: 520)
            .scaleEffect(appeared ? 1 : 0.98)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -4)
        }
        .onAppear {
            switch state.paletteContext {
            case .modelSelect, .tabModelSelect:
                isContextModelMode = true
            case .general:
                isContextModelMode = false
            }
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
            if isContextModelMode {
                selectHighlightedContextModel()
            } else {
                selectHighlighted()
            }
            return .handled
        }
        .onKeyPress(.tab) {
            if isContextModelMode {
                return .ignored
            }
            if step == .endpoints {
                switchToBookmarks()
            } else if step == .bookmarks {
                switchToEndpoints()
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if step == .bookmarks {
                deleteHighlightedBookmark()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if isContextModelMode {
                dismiss()
            } else if step == .models {
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

    private static let outputOrder: [OutputType] = [.text, .image, .audio, .video]

    private var flatEndpointItems: [PaletteItem] {
        let all = state.definitionLoader.definitionsByOutputType
        let query = searchText.lowercased()
        var items: [PaletteItem] = []
        var flatIdx = 0

        for type in Self.outputOrder {
            guard let defs = all[type], !defs.isEmpty else { continue }
            var sectionItems: [PaletteItem] = []

            for def in defs {
                if query.isEmpty {
                    // No search — show all endpoints, no model rows
                    sectionItems.append(.endpoint(def, flatIdx))
                    flatIdx += 1
                } else {
                    let nameMatch = def.name.lowercased().contains(query) ||
                        def.provider.lowercased().contains(query) ||
                        def.providerDisplayName.lowercased().contains(query)

                    // Find matching models for this definition
                    let matchingModels = (def.modelParam?.options ?? []).filter {
                        $0.lowercased().contains(query)
                    }

                    if nameMatch {
                        // Endpoint name/provider matches — show the endpoint row
                        sectionItems.append(.endpoint(def, flatIdx))
                        flatIdx += 1
                    } else if !matchingModels.isEmpty {
                        // Only models match — show a non-selectable endpoint header, then model rows
                        sectionItems.append(.endpoint(def, -1))
                    }

                    // Show matching model rows for direct selection
                    if !matchingModels.isEmpty {
                        for model in matchingModels {
                            sectionItems.append(.model(def, model, flatIdx))
                            flatIdx += 1
                        }
                    }
                }
            }

            if !sectionItems.isEmpty {
                items.append(.header(type))
                items.append(contentsOf: sectionItems)
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
                    .font(.system(size: DS.Font.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

            case .providerHeader:
                EmptyView()

            case .endpoint(let def, let flatIndex):
                let hasKey = state.keyStatus[def.provider] != .noKey
                let isSelectableEndpoint = flatIndex >= 0

                Button {
                    if isSelectableEndpoint {
                        selectEndpoint(def)
                    }
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: def.outputType.iconName)
                            .font(.system(size: DS.Font.secondary))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                            .padding(.trailing, 8)

                        Text(def.providerDisplayName)
                            .font(.system(size: DS.Font.secondary))
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, 6)

                        Text(def.name)
                            .font(.system(size: DS.Font.body))
                            .foregroundStyle(hasKey ? .primary : .tertiary)

                        Spacer()

                        if def.modelCount > 0 {
                            Text("\(def.modelCount) models")
                                .font(.system(size: DS.Font.caption))
                                .foregroundStyle(.secondary)
                        }

                        if !hasKey {
                            Text("no key")
                                .font(.system(size: DS.Font.caption))
                                .foregroundStyle(Color.accentColor)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        isSelectableEndpoint && flatIndex == highlightedIndex
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(hasKey ? 1.0 : (isSelectableEndpoint ? 0.4 : 0.6))
                .disabled(!isSelectableEndpoint)

            case .model(let def, let modelName, let flatIndex):
                let hasKey = state.keyStatus[def.provider] != .noKey

                Button {
                    state.selectEndpoint(def, model: modelName)
                    SoundService.select()
                    dismiss()
                } label: {
                    HStack(spacing: 0) {
                        // Indent to align under endpoint text
                        Color.clear
                            .frame(width: 20)
                            .padding(.trailing, 8)

                        Image(systemName: "cpu")
                            .font(.system(size: DS.Font.caption))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                            .padding(.trailing, 6)

                        Text(modelName)
                            .font(.system(size: DS.Font.secondary))
                            .foregroundStyle(hasKey ? .primary : .tertiary)

                        if modelName == def.defaultModel {
                            Text("default")
                                .font(.system(size: DS.Font.caption))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quinary)
                                .clipShape(Capsule())
                                .padding(.leading, 4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        flatIndex == highlightedIndex
                            ? Color.accentColor.opacity(0.15)
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
                        .font(.system(size: DS.Font.body))
                        .foregroundStyle(.primary)

                    if isDefault {
                        Text("default")
                            .font(.system(size: DS.Font.caption))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quinary)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    index == highlightedIndex
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filtering

    private var totalFilteredCount: Int {
        flatEndpointItems.reduce(0) { count, item in
            switch item {
            case .endpoint(_, let idx) where idx >= 0: return count + 1
            case .model: return count + 1
            default: return count
            }
        }
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
        let count: Int
        if isContextModelMode {
            count = contextModelSelectableCount
        } else {
            switch step {
            case .endpoints: count = totalFilteredCount
            case .models: count = filteredModels.count
            case .bookmarks: count = filteredBookmarks.count
            }
        }
        guard count > 0 else { return }
        highlightedIndex = (highlightedIndex + delta + count) % count
    }

    private func selectHighlighted() {
        switch step {
        case .endpoints:
            for item in flatEndpointItems {
                if case .endpoint(let def, let idx) = item, idx >= 0, idx == highlightedIndex {
                    selectEndpoint(def)
                    return
                }
                if case .model(let def, let modelName, let idx) = item, idx == highlightedIndex {
                    state.selectEndpoint(def, model: modelName)
                    SoundService.select()
                    dismiss()
                    return
                }
            }
        case .models:
            let models = filteredModels
            if highlightedIndex < models.count {
                selectModel(models[highlightedIndex])
            }
        case .bookmarks:
            let bookmarks = filteredBookmarks
            if highlightedIndex < bookmarks.count {
                state.loadBookmark(bookmarks[highlightedIndex])
                dismiss()
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
            state.paletteContext = .general
        }
    }

    // MARK: - Bookmark List

    @ViewBuilder
    private var bookmarkList: some View {
        let bookmarks = filteredBookmarks
        if bookmarks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .font(.system(size: DS.Font.display))
                    .foregroundStyle(.quaternary.opacity(0.4))
                Text(searchText.isEmpty ? "No bookmarks yet" : "No matching bookmarks")
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(.secondary)
                if searchText.isEmpty {
                    Text("Save one with \u{2318}D")
                        .font(.system(size: DS.Font.secondary))
                        .foregroundStyle(.quaternary.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                let definition = state.definitionLoader.sortedDefinitions.first { $0.id == bookmark.definitionId }
                let isHovered = hoveredBookmarkId == bookmark.id

                Button {
                    state.loadBookmark(bookmark)
                    SoundService.select()
                    dismiss()
                } label: {
                    HStack(spacing: 0) {
                        // Output type accent bar
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(outputTypeColor(definition?.outputType))
                            .frame(width: 3, height: 24)
                            .padding(.trailing, 12)

                        // Bookmark icon
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: DS.Font.caption))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                            .frame(width: 16)
                            .padding(.trailing, 6)

                        // Label + endpoint info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.label)
                                .font(.system(size: DS.Font.body))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                if bookmark.isTabGroup, let entries = bookmark.tabGroup {
                                    Image(systemName: "square.split.2x1")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                    Text("\(entries.count) models")
                                        .foregroundStyle(.secondary)
                                } else if let def = definition {
                                    Text(def.providerDisplayName)
                                        .foregroundStyle(.secondary)
                                    if let model = bookmark.model {
                                        Text("\u{00B7}")
                                            .foregroundStyle(.quaternary.opacity(0.5))
                                        Text(model.split(separator: "/").last.map(String.init) ?? model)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .font(.system(size: DS.Font.caption))
                            .lineLimit(1)
                        }

                        Spacer()

                        // Time ago
                        Text(timeAgo(bookmark.createdAt))
                            .font(.system(size: DS.Font.caption))
                            .foregroundStyle(.secondary)

                        // Delete button (hover reveal)
                        if isHovered {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    state.deleteBookmark(bookmark)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: DS.Font.caption))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        index == highlightedIndex
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        hoveredBookmarkId = hovering ? bookmark.id : nil
                    }
                }
            }
        }
    }

    private var filteredBookmarks: [Bookmark] {
        let all = state.bookmarkStore.bookmarks
        if searchText.isEmpty { return all }
        let query = searchText.lowercased()
        return all.filter {
            $0.label.lowercased().contains(query) ||
            $0.definitionId.lowercased().contains(query) ||
            ($0.model?.lowercased().contains(query) ?? false)
        }
    }

    private func switchToBookmarks() {
        withAnimation(.easeOut(duration: 0.15)) {
            step = .bookmarks
            searchText = ""
            highlightedIndex = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isSearchFocused = true
        }
    }

    private func switchToEndpoints() {
        withAnimation(.easeOut(duration: 0.15)) {
            step = .endpoints
            searchText = ""
            highlightedIndex = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isSearchFocused = true
        }
    }

    private func deleteHighlightedBookmark() {
        let bookmarks = filteredBookmarks
        guard highlightedIndex < bookmarks.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.deleteBookmark(bookmarks[highlightedIndex])
        }
        if highlightedIndex >= filteredBookmarks.count {
            highlightedIndex = max(0, filteredBookmarks.count - 1)
        }
    }

    private var searchPlaceholder: String {
        if isContextModelMode { return "Search models..." }
        switch step {
        case .endpoints: return "Search endpoints or models..."
        case .models: return "Search models..."
        case .bookmarks: return "Search bookmarks..."
        }
    }

    // MARK: - Context Model Selection (for .modelSelect / .tabModelSelect)

    private var flatContextModelItems: [PaletteItem] {
        let query = searchText.lowercased()
        var items: [PaletteItem] = []
        var flatIdx = 0

        // Group definitions by provider, only show providers with valid keys
        var providerDefs: [(String, [Definition])] = []
        var seenProviders: [String] = []

        for definition in state.definitionLoader.sortedDefinitions {
            guard state.keyStatus[definition.provider] == .valid else { continue }
            guard let models = definition.modelParam?.options, !models.isEmpty else { continue }

            if !seenProviders.contains(definition.provider) {
                seenProviders.append(definition.provider)
                providerDefs.append((definition.providerDisplayName, [definition]))
            } else if let idx = providerDefs.firstIndex(where: { $0.0 == definition.providerDisplayName }) {
                providerDefs[idx].1.append(definition)
            }
        }

        for (providerName, defs) in providerDefs {
            var sectionItems: [PaletteItem] = []

            for def in defs {
                let models = def.modelParam?.options ?? []
                let filtered: [String]
                if query.isEmpty {
                    filtered = models
                } else {
                    filtered = models.filter {
                        $0.lowercased().contains(query) ||
                        def.providerDisplayName.lowercased().contains(query) ||
                        def.provider.lowercased().contains(query)
                    }
                }
                for model in filtered {
                    sectionItems.append(.model(def, model, flatIdx))
                    flatIdx += 1
                }
            }

            if !sectionItems.isEmpty {
                items.append(.providerHeader(providerName))
                items.append(contentsOf: sectionItems)
            }
        }
        return items
    }

    private var contextModelSelectableCount: Int {
        flatContextModelItems.reduce(0) { count, item in
            if case .model = item { return count + 1 }
            return count
        }
    }

    @ViewBuilder
    private var contextModelList: some View {
        let items = flatContextModelItems

        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: DS.Font.display))
                    .foregroundStyle(.quaternary.opacity(0.4))
                Text(searchText.isEmpty ? "No models available" : "No matching models")
                    .font(.system(size: DS.Font.body))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ForEach(items) { item in
                switch item {
                case .providerHeader(let name):
                    Text(name)
                        .font(.system(size: DS.Font.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                case .model(let def, let modelName, let flatIndex):
                    let isCurrentModel = state.currentDefinition?.id == def.id && state.currentModel == modelName

                    Button {
                        selectContextModel(definition: def, model: modelName)
                    } label: {
                        HStack(spacing: 0) {
                            Image(systemName: "cpu")
                                .font(.system(size: DS.Font.caption))
                                .foregroundStyle(.tertiary)
                                .frame(width: 14)
                                .padding(.trailing, 6)

                            Text(modelName)
                                .font(.system(size: DS.Font.body))
                                .foregroundStyle(.primary)

                            if modelName == def.defaultModel {
                                Text("default")
                                    .font(.system(size: DS.Font.caption))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quinary)
                                    .clipShape(Capsule())
                                    .padding(.leading, 4)
                            }

                            Spacer()

                            if isCurrentModel {
                                Image(systemName: "checkmark")
                                    .font(.system(size: DS.Font.secondary, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            flatIndex == highlightedIndex
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                default:
                    EmptyView()
                }
            }
        }
    }

    private func selectContextModel(definition: Definition, model: String) {
        switch state.paletteContext {
        case .modelSelect:
            state.selectEndpoint(definition, model: model)
        case .tabModelSelect(let index):
            state.updateTabModel(at: index, definition: definition, model: model)
        case .general:
            break
        }
        SoundService.select()
        dismiss()
    }

    private func selectHighlightedContextModel() {
        for item in flatContextModelItems {
            if case .model(let def, let modelName, let idx) = item, idx == highlightedIndex {
                selectContextModel(definition: def, model: modelName)
                return
            }
        }
    }

    private func outputTypeColor(_ type: OutputType?) -> Color {
        switch type {
        case .text: return .blue
        case .image: return .purple
        case .audio: return .accentColor
        case .video: return .green
        case .none: return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "yesterday" }
        if days < 30 { return "\(days)d ago" }
        return "\(days / 30)mo ago"
    }

    // MARK: - Tab Pill

    private func tabPill(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: DS.Font.caption, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isActive ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hint Label

    private func hintLabel(key: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: DS.Font.caption, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            Text(text)
                .font(.system(size: DS.Font.caption))
                .foregroundStyle(.secondary)
        }
    }
}
