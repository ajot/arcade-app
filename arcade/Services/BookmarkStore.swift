import Foundation

@Observable
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Arcade")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bookmarks.json")
    }

    init() {
        load()
    }

    func save(_ bookmark: Bookmark) {
        bookmarks.insert(bookmark, at: 0)
        persist()
    }

    func delete(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        bookmarks = (try? decoder.decode([Bookmark].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(bookmarks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
