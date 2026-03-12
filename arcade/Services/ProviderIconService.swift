import AppKit
import Foundation

/// Fetches, caches, and serves provider favicon icons.
@Observable
final class ProviderIconService {
    private var cache: [String: NSImage] = [:]
    private var fetchingProviders: Set<String> = []

    private var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Arcade/IconCache", isDirectory: true)
    }

    /// Returns the cached icon for a provider, or kicks off a fetch if not cached.
    func icon(for provider: String, iconUrl: String?) -> NSImage? {
        if let cached = cache[provider] {
            return cached
        }

        // Try loading from disk cache
        let diskPath = cacheDirectory.appendingPathComponent("\(provider).png")
        if let image = NSImage(contentsOf: diskPath) {
            cache[provider] = image
            return image
        }

        // Kick off fetch if we have a URL and aren't already fetching
        if let urlString = iconUrl, let url = URL(string: urlString), !fetchingProviders.contains(provider) {
            fetchingProviders.insert(provider)
            Task {
                await fetchIcon(provider: provider, url: url)
            }
        }

        return nil
    }

    private func fetchIcon(provider: String, url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else { return }

            // Save to disk cache
            let dir = cacheDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let diskPath = dir.appendingPathComponent("\(provider).png")
            if let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try png.write(to: diskPath)
            }

            await MainActor.run {
                self.cache[provider] = image
                self.fetchingProviders.remove(provider)
            }
        } catch {
            await MainActor.run { [self] in
                _ = self.fetchingProviders.remove(provider)
            }
        }
    }
}
