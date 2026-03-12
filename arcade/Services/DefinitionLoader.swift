import Foundation
import AppKit

/// Loads endpoint definitions from a writable directory.
/// On first launch, bundled definitions are copied there so users can edit, add, or remove them.
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
        seedBundledDefinitionsIfNeeded()
        loadDefinitions()
    }

    func definition(for id: String) -> Definition? {
        definitions[id]
    }

    /// Re-scans definitions from the writable directory.
    func reload() {
        definitions.removeAll()
        loadErrors.removeAll()
        loadDefinitions()
    }

    /// Opens the definitions directory in Finder.
    func showDefinitionsFolder() {
        let dir = definitionsDirectory
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(dir)
    }

    // MARK: - Seeding

    /// On first launch, copies all bundled definitions into the writable directory.
    /// Only copies files that don't already exist — preserves user edits.
    private func seedBundledDefinitionsIfNeeded() {
        let fm = FileManager.default
        let dir = definitionsDirectory

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return }
        for url in bundledURLs {
            let dest = dir.appendingPathComponent(url.lastPathComponent)
            // Only copy if the file doesn't already exist — don't overwrite user edits
            if !fm.fileExists(atPath: dest.path) {
                try? fm.copyItem(at: url, to: dest)
            }
        }
    }

    /// Copies all bundled definitions into the writable directory, overwriting existing files.
    /// User-added definitions (not in the bundle) are preserved.
    func restoreBundledDefinitions() {
        let fm = FileManager.default
        let dir = definitionsDirectory

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return }
        for url in bundledURLs {
            let dest = dir.appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try? fm.removeItem(at: dest)
            }
            try? fm.copyItem(at: url, to: dest)
        }

        reload()
    }

    // MARK: - Loading

    private func loadDefinitions() {
        let dir = definitionsDirectory
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: dir,
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

    private var definitionsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Arcade/Definitions", isDirectory: true)
    }
}
