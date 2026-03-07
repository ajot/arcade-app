import Foundation

/// Loads endpoint definitions from bundled JSON files and an optional user directory.
@Observable
final class DefinitionLoader {
    private(set) var definitions: [String: Definition] = [:]
    private(set) var loadErrors: [String] = []

    /// All definitions sorted by name.
    var sortedDefinitions: [Definition] {
        definitions.values.sorted { $0.name < $1.name }
    }

    /// Unique providers with display names.
    var providers: [(slug: String, displayName: String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for def in sortedDefinitions {
            if seen.insert(def.provider).inserted {
                result.append((def.provider, def.providerDisplayName))
            }
        }
        return result
    }

    /// Definitions grouped by output type.
    var definitionsByOutputType: [OutputType: [Definition]] {
        Dictionary(grouping: sortedDefinitions, by: \.outputType)
    }

    /// Total endpoint count.
    var endpointCount: Int { definitions.count }

    /// Total unique provider count.
    var providerCount: Int {
        Set(definitions.values.map(\.provider)).count
    }

    init() {
        loadBundledDefinitions()
        loadUserDefinitions()
    }

    func definition(for id: String) -> Definition? {
        definitions[id]
    }

    // MARK: - Loading

    private func loadBundledDefinitions() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return
        }

        for url in urls {
            loadDefinition(at: url)
        }
    }

    private func loadUserDefinitions() {
        let userDir = userDefinitionsDirectory
        let fm = FileManager.default

        // Create directory if it doesn't exist
        if !fm.fileExists(atPath: userDir.path) {
            try? fm.createDirectory(at: userDir, withIntermediateDirectories: true)
        }

        guard let enumerator = fm.enumerator(
            at: userDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "json" {
                loadDefinition(at: url)
            }
        }
    }

    private func loadDefinition(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let definition = try decoder.decode(Definition.self, from: data)
            definitions[definition.id] = definition
        } catch {
            loadErrors.append("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private var userDefinitionsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Arcade/Definitions", isDirectory: true)
    }
}
