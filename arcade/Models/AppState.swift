import Foundation
import SwiftUI

/// Central app state managing mode, selections, and generation.
@Observable
final class AppState {
    // MARK: - Dependencies
    let definitionLoader = DefinitionLoader()
    let networkService = NetworkService()
    let bookmarkStore = BookmarkStore()

    // MARK: - Appearance Preferences
    var appearanceMode: String = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system" {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode") }
    }
    var accentColorName: String = UserDefaults.standard.string(forKey: "accentColorName") ?? "amber" {
        didSet { UserDefaults.standard.set(accentColorName, forKey: "accentColorName") }
    }

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var accentColor: Color {
        switch accentColorName {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "pink": return .pink
        default: return Color(red: 0.961, green: 0.620, blue: 0.043) // amber #f59e0b
        }
    }

    let iconService = ProviderIconService()

    // MARK: - Navigation
    var showSidebar = true
    var showCommandPalette = false
    var showBookmarkPopover = false
    var showCurlPopover = false
    var showInspector = false
    var zoomedImageValue: String?
    var settingsTab: SettingsTab = .general

    enum PaletteContext {
        case general              // Normal Cmd+K
        case modelSelect          // Picking model for compose area
        case tabModelSelect(Int)  // Picking model for a specific comparison tab
    }

    var paletteContext: PaletteContext = .general

    enum SettingsTab: Hashable {
        case general
        case apiKeys
    }

    // MARK: - Compare Mode

    struct Tab: Identifiable {
        let id = UUID()
        var definition: Definition
        var model: String
        var result: GenerationResult?
        var streamedText: String = ""
        var streamingMetrics: StreamingResult?
        var generationState: GenerationState = .idle
    }

    var tabs: [Tab] = []
    var activeTabIndex: Int = 0
    var isCompareMode: Bool = false
    var showReport: Bool = false

    // MARK: - Play Mode State
    var currentDefinition: Definition?
    var currentModel: String?
    var formValues: [String: String] = [:]
    var systemPrompt: String = ""

    // MARK: - Generation State
    enum GenerationState: Equatable {
        case idle
        case generating
        case streaming
        case polling(String) // status message
        case completed
        case error(String)
    }

    var generationState: GenerationState = .idle
    var streamedText: String = ""
    var generationResult: GenerationResult?
    var streamingMetrics: StreamingResult?
    var currentTask: Task<Void, Never>?
    var lastRequestBody: String?
    var lastResponseBody: String?

    // MARK: - Log Panel
    var showLogPanel = false
    var logEntries: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let kind: Kind
        let message: String
        var detail: String?

        enum Kind {
            case request
            case response
            case polling
            case success
            case error
        }
    }

    func log(_ kind: LogEntry.Kind, _ message: String, detail: String? = nil) {
        logEntries.append(LogEntry(kind: kind, message: message, detail: detail))
    }

    func clearLog() {
        logEntries.removeAll()
    }

    // MARK: - API Key Status
    var keyStatus: [String: KeyStatus] = [:]

    enum KeyStatus: Equatable {
        case valid
        case invalid
        case noKey
        case unknown
        case checking
    }

    // MARK: - Actions

    func selectEndpoint(_ definition: Definition, model: String? = nil) {
        currentDefinition = definition
        currentModel = model ?? definition.defaultModel
        showCommandPalette = false

        // Initialize form values with defaults
        formValues = [:]
        for param in definition.request.params {
            if param.name == "model" { continue }
            if let defaultStr = param.defaultDisplayString {
                formValues[param.name] = defaultStr
            }
        }
        systemPrompt = ""

        // Reset generation
        cancelGeneration()
        generationState = .idle
        streamedText = ""
        generationResult = nil
        streamingMetrics = nil

        // Keep active tab in sync
        syncActiveTab()
    }

    func syncActiveTab() {
        guard isCompareMode, activeTabIndex < tabs.count,
              let def = currentDefinition, let model = currentModel else { return }
        tabs[activeTabIndex].definition = def
        tabs[activeTabIndex].model = model
    }

    func selectModel(_ model: String) {
        currentModel = model
        syncActiveTab()
    }

    func fillExample(_ example: Example) {
        for (key, value) in example.params {
            if key == "model" { continue }
            switch value {
            case .string(let s): formValues[key] = s
            case .int(let i): formValues[key] = "\(i)"
            case .double(let d): formValues[key] = "\(d)"
            default: break
            }
        }
    }

    func goHome() {
        cancelGeneration()
        currentDefinition = nil
        currentModel = nil
        formValues = [:]
        systemPrompt = ""
        generationState = .idle
        streamedText = ""
        generationResult = nil
        streamingMetrics = nil
    }

    // MARK: - Bookmarks

    func saveBookmark(label: String, selectedTabIds: Set<UUID>? = nil) {
        guard let definition = currentDefinition else { return }

        // If in compare mode, save selected tabs as group
        let tabEntries: [Bookmark.TabEntry]?
        if isCompareMode && tabs.count > 1 {
            let selectedTabs = selectedTabIds.map { ids in
                tabs.filter { ids.contains($0.id) }
            } ?? tabs
            tabEntries = selectedTabs.count > 1
                ? selectedTabs.map { Bookmark.TabEntry(definitionId: $0.definition.id, model: $0.model) }
                : nil
        } else {
            tabEntries = nil
        }

        let bookmark = Bookmark(
            definitionId: definition.id,
            model: currentModel,
            label: label,
            formValues: formValues,
            systemPrompt: systemPrompt,
            tabGroup: tabEntries
        )
        bookmarkStore.save(bookmark)
        SoundService.bookmark()
    }

    func loadBookmark(_ bookmark: Bookmark) {
        guard let definition = definitionLoader.sortedDefinitions.first(where: { $0.id == bookmark.definitionId }) else { return }
        selectEndpoint(definition, model: bookmark.model)
        formValues = bookmark.formValues
        systemPrompt = bookmark.systemPrompt

        // Restore tab group if present
        if let tabEntries = bookmark.tabGroup, tabEntries.count > 1 {
            var restoredTabs: [Tab] = []
            for entry in tabEntries {
                if let def = definitionLoader.sortedDefinitions.first(where: { $0.id == entry.definitionId }) {
                    restoredTabs.append(Tab(definition: def, model: entry.model))
                }
            }
            if restoredTabs.count > 1 {
                tabs = restoredTabs
                activeTabIndex = 0
                isCompareMode = true
            }
        } else {
            // Single bookmark — exit compare mode if active
            if isCompareMode {
                exitCompareMode()
            }
        }

        SoundService.select()
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        bookmarkStore.delete(id: bookmark.id)
    }

    // MARK: - Generation

    func generate() {
        guard let definition = currentDefinition else { return }
        guard let apiKey = KeychainService.getKey(for: definition.provider) else {
            generationState = .error("No API key for \(definition.providerDisplayName)")
            return
        }

        // Build params including model
        var params = formValues
        if let model = currentModel {
            params["model"] = model
        }
        if !systemPrompt.isEmpty {
            params["_system_prompt"] = systemPrompt
        }

        cancelGeneration()
        streamedText = ""
        generationResult = nil
        streamingMetrics = nil
        lastResponseBody = nil
        SoundService.generate()

        // Build request body JSON for display
        if let built = try? RequestBuilder.buildRequest(definition: definition, params: params, apiKey: apiKey),
           let body = built.body,
           let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            lastRequestBody = jsonString
        }

        // Build curl string for log
        let curlDetail = try? RequestBuilder.buildCurlString(
            definition: definition, params: params,
            includeKey: false, apiKey: nil
        )

        let pattern = definition.interaction.pattern
        log(.request, "\(definition.request.method) \(definition.request.url) (\(pattern.rawValue))", detail: curlDetail)

        switch pattern {
        case .streaming:
            generationState = .streaming
            currentTask = Task { @MainActor in
                do {
                    let metrics = try await networkService.sendStreaming(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    ) { [weak self] token in
                        Task { @MainActor in
                            self?.streamedText += token
                        }
                    }
                    self.streamingMetrics = metrics
                    self.generationState = .completed
                    self.log(.success, "Completed — \(metrics.tokenCount) tokens in \(String(format: "%.2fs", metrics.totalDuration))")
                    SoundService.complete()
                } catch is CancellationError {
                    self.generationState = .idle
                    self.log(.error, "Cancelled")
                } catch {
                    self.generationState = .error(error.localizedDescription)
                    self.log(.error, error.localizedDescription)
                    SoundService.error()
                }
            }

        case .sync:
            generationState = .generating
            currentTask = Task { @MainActor in
                do {
                    let result = try await networkService.sendSync(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    )
                    self.generationResult = result
                    self.lastResponseBody = self.prettyJSON(result.rawResponse)
                    if let textOutput = result.outputs.first(where: { $0.type == .text }),
                       let text = textOutput.values.first {
                        self.streamedText = text
                    }
                    self.generationState = .completed
                    self.log(.response, "\(result.statusCode) — \(String(format: "%.2fs", result.duration))")
                    SoundService.complete()
                } catch is CancellationError {
                    self.generationState = .idle
                    self.log(.error, "Cancelled")
                } catch {
                    self.generationState = .error(error.localizedDescription)
                    self.log(.error, error.localizedDescription)
                    SoundService.error()
                }
            }

        case .polling:
            generationState = .polling("Submitting...")
            currentTask = Task { @MainActor in
                do {
                    let result = try await networkService.sendPolling(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    ) { [weak self] status in
                        Task { @MainActor in
                            self?.generationState = .polling(status)
                            self?.log(.polling, status)
                        }
                    }
                    self.generationResult = result
                    self.lastResponseBody = self.prettyJSON(result.rawResponse)
                    self.generationState = .completed
                    self.log(.success, "Completed — \(result.pollCount) polls, \(String(format: "%.2fs", result.duration))")
                    SoundService.complete()
                } catch is CancellationError {
                    self.generationState = .idle
                    self.log(.error, "Cancelled")
                } catch {
                    self.generationState = .error(error.localizedDescription)
                    self.log(.error, error.localizedDescription)
                    SoundService.error()
                }
            }
        }
    }

    // MARK: - Compare Mode Generation

    func generateAllTabs() {
        for i in tabs.indices {
            generateTab(at: i)
        }
    }

    func generateTab(at index: Int) {
        guard index < tabs.count else { return }
        let tab = tabs[index]
        let definition = tab.definition
        let model = tab.model

        guard let apiKey = KeychainService.getKey(for: definition.provider) else {
            tabs[index].generationState = .error("No API key for \(definition.providerDisplayName)")
            return
        }

        // Build params including model
        var params = formValues
        params["model"] = model
        if !systemPrompt.isEmpty {
            params["_system_prompt"] = systemPrompt
        }

        // Reset tab state
        tabs[index].streamedText = ""
        tabs[index].result = nil
        tabs[index].streamingMetrics = nil
        SoundService.generate()

        let pattern = definition.interaction.pattern

        switch pattern {
        case .streaming:
            tabs[index].generationState = .streaming
            Task { @MainActor in
                do {
                    let metrics = try await networkService.sendStreaming(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    ) { [weak self] token in
                        Task { @MainActor in
                            guard let self, index < self.tabs.count else { return }
                            self.tabs[index].streamedText += token
                        }
                    }
                    guard index < tabs.count else { return }
                    tabs[index].streamingMetrics = metrics
                    tabs[index].generationState = .completed
                    log(.success, "[\(definition.providerDisplayName)] Completed — \(metrics.tokenCount) tokens in \(String(format: "%.2fs", metrics.totalDuration))")
                    SoundService.complete()
                } catch is CancellationError {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .idle
                } catch {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .error(error.localizedDescription)
                    log(.error, "[\(definition.providerDisplayName)] \(error.localizedDescription)")
                    SoundService.error()
                }
            }

        case .sync:
            tabs[index].generationState = .generating
            Task { @MainActor in
                do {
                    let result = try await networkService.sendSync(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    )
                    guard index < tabs.count else { return }
                    tabs[index].result = result
                    if let textOutput = result.outputs.first(where: { $0.type == .text }),
                       let text = textOutput.values.first {
                        tabs[index].streamedText = text
                    }
                    tabs[index].generationState = .completed
                    log(.response, "[\(definition.providerDisplayName)] \(result.statusCode) — \(String(format: "%.2fs", result.duration))")
                    SoundService.complete()
                } catch is CancellationError {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .idle
                } catch {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .error(error.localizedDescription)
                    log(.error, "[\(definition.providerDisplayName)] \(error.localizedDescription)")
                    SoundService.error()
                }
            }

        case .polling:
            tabs[index].generationState = .polling("Submitting...")
            Task { @MainActor in
                do {
                    let result = try await networkService.sendPolling(
                        definition: definition,
                        params: params,
                        apiKey: apiKey
                    ) { [weak self] status in
                        Task { @MainActor in
                            guard let self, index < self.tabs.count else { return }
                            self.tabs[index].generationState = .polling(status)
                        }
                    }
                    guard index < tabs.count else { return }
                    tabs[index].result = result
                    tabs[index].generationState = .completed
                    log(.success, "[\(definition.providerDisplayName)] Completed — \(result.pollCount) polls, \(String(format: "%.2fs", result.duration))")
                    SoundService.complete()
                } catch is CancellationError {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .idle
                } catch {
                    guard index < tabs.count else { return }
                    tabs[index].generationState = .error(error.localizedDescription)
                    log(.error, "[\(definition.providerDisplayName)] \(error.localizedDescription)")
                    SoundService.error()
                }
            }
        }
    }

    // MARK: - Compare Mode Report

    func generateReport() {
        guard isCompareMode else { return }
        let completedTabs = tabs.filter { $0.generationState == .completed }
        guard completedTabs.count >= 2 else { return }
        showReport = true
    }

    func closeReport() {
        showReport = false
    }

    // MARK: - Compare Mode Actions

    func enterCompareMode() {
        guard let def = currentDefinition, let model = currentModel else { return }
        if tabs.isEmpty {
            tabs = [Tab(definition: def, model: model)]
        }
        isCompareMode = true
        addTab()
    }

    func exitCompareMode() {
        isCompareMode = false
        if let activeTab = tabs[safe: activeTabIndex] {
            selectEndpoint(activeTab.definition, model: activeTab.model)
        }
        tabs = []
        activeTabIndex = 0
    }

    func addTab() {
        let usedDefIds = Set(tabs.map { $0.definition.id })
        if let newDef = definitionLoader.sortedDefinitions.first(where: { def in
            !usedDefIds.contains(def.id) &&
            def.outputType == currentDefinition?.outputType &&
            keyStatus[def.provider] == .valid
        }) {
            let model = newDef.defaultModel ?? newDef.modelParam?.options?.first ?? ""
            tabs.append(Tab(definition: newDef, model: model))
            activeTabIndex = tabs.count - 1
            currentDefinition = newDef
            currentModel = model
        }
    }

    func removeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        tabs.remove(at: index)
        if activeTabIndex >= tabs.count { activeTabIndex = tabs.count - 1 }
        if tabs.count == 1 {
            exitCompareMode()
        } else {
            currentDefinition = tabs[activeTabIndex].definition
            currentModel = tabs[activeTabIndex].model
        }
    }

    func selectTab(_ index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabIndex = index
        currentDefinition = tabs[index].definition
        currentModel = tabs[index].model
    }

    func updateTabModel(at index: Int, definition: Definition, model: String) {
        guard index >= 0 && index < tabs.count else { return }
        tabs[index].definition = definition
        tabs[index].model = model
        tabs[index].result = nil
        tabs[index].streamedText = ""
        tabs[index].streamingMetrics = nil
        tabs[index].generationState = .idle

        // Sync if this is the active tab
        if index == activeTabIndex {
            currentDefinition = definition
            currentModel = model
        }
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Key Validation

    var keysValidated = false

    func validateAllKeys() {
        let providers = definitionLoader.providers
        for (slug, _) in providers {
            if KeychainService.getKey(for: slug) != nil {
                keyStatus[slug] = .checking
            } else {
                keyStatus[slug] = .noKey
            }
        }

        Task {
            var results: [(String, KeyStatus)] = []
            await withTaskGroup(of: (String, KeyStatus).self) { group in
                for (slug, _) in providers {
                    guard let apiKey = KeychainService.getKey(for: slug) else { continue }
                    group.addTask {
                        await self.checkKey(slug: slug, apiKey: apiKey)
                    }
                }

                for await result in group {
                    results.append(result)
                }
            }

            await MainActor.run {
                for (provider, status) in results {
                    self.keyStatus[provider] = status
                }
                self.keysValidated = true
            }
        }
    }

    func validateKey(for slug: String) {
        guard let apiKey = KeychainService.getKey(for: slug) else {
            keyStatus[slug] = .noKey
            return
        }
        keyStatus[slug] = .checking
        Task {
            let (provider, status) = await checkKey(slug: slug, apiKey: apiKey)
            await MainActor.run {
                self.keyStatus[provider] = status
            }
        }
    }

    private func checkKey(slug: String, apiKey: String) async -> (String, KeyStatus) {
        let defs = definitionLoader.sortedDefinitions.filter { $0.provider == slug }
        guard let definition = defs.first,
              let validationUrl = definition.auth.validationUrl,
              let url = URL(string: validationUrl) else {
            return (slug, .unknown)
        }

        let auth = definition.auth
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "\(auth.prefix)\(apiKey)",
            forHTTPHeaderField: auth.header
        )

        do {
            // Use a delegate to cancel after receiving headers (avoid downloading large responses)
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300: return (slug, .valid)
            case 401, 403: return (slug, .invalid)
            default: return (slug, .unknown)
            }
        } catch {
            return (slug, .unknown)
        }
    }

    private func prettyJSON(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    /// Whether the current endpoint has a valid API key.
    var hasValidKey: Bool {
        guard let provider = currentDefinition?.provider else { return false }
        return KeychainService.getKey(for: provider) != nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
