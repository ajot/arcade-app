import Foundation
import SwiftUI

/// Central app state managing mode, selections, and generation.
@Observable
final class AppState {
    // MARK: - Dependencies
    let definitionLoader = DefinitionLoader()
    let networkService = NetworkService()
    let bookmarkStore = BookmarkStore()

    // MARK: - Navigation
    var showCommandPalette = false
    var showBookmarkPopover = false
    var showInspector = false
    var zoomedImageValue: String?
    var settingsTab: SettingsTab = .general

    enum SettingsTab: Hashable {
        case general
        case apiKeys
    }

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
    }

    func selectModel(_ model: String) {
        currentModel = model
    }

    func fillExample(_ example: Example) {
        for (key, value) in example.params {
            if key == "model" {
                if let s = value.stringValue {
                    currentModel = s
                }
                continue
            }
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

    func saveBookmark(label: String) {
        guard let definition = currentDefinition else { return }
        let bookmark = Bookmark(
            definitionId: definition.id,
            model: currentModel,
            label: label,
            formValues: formValues,
            systemPrompt: systemPrompt
        )
        bookmarkStore.save(bookmark)
        SoundService.bookmark()
    }

    func loadBookmark(_ bookmark: Bookmark) {
        guard let definition = definitionLoader.sortedDefinitions.first(where: { $0.id == bookmark.definitionId }) else { return }
        selectEndpoint(definition, model: bookmark.model)
        formValues = bookmark.formValues
        systemPrompt = bookmark.systemPrompt
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

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Key Validation

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
            await withTaskGroup(of: (String, KeyStatus).self) { group in
                for (slug, _) in providers {
                    guard let apiKey = KeychainService.getKey(for: slug) else { continue }
                    group.addTask {
                        await self.checkKey(slug: slug, apiKey: apiKey)
                    }
                }

                for await (provider, status) in group {
                    await MainActor.run {
                        self.keyStatus[provider] = status
                    }
                }
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
