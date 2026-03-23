import Foundation

struct Bookmark: Codable, Identifiable {
    let id: UUID
    let definitionId: String
    let model: String?
    let label: String
    let formValues: [String: String]
    let systemPrompt: String
    let createdAt: Date
    let tabGroup: [TabEntry]?

    /// A single tab entry in a tab group bookmark
    struct TabEntry: Codable {
        let definitionId: String
        let model: String
    }

    var isTabGroup: Bool { tabGroup != nil && (tabGroup?.count ?? 0) > 1 }

    init(
        definitionId: String,
        model: String?,
        label: String,
        formValues: [String: String],
        systemPrompt: String,
        tabGroup: [TabEntry]? = nil
    ) {
        self.id = UUID()
        self.definitionId = definitionId
        self.model = model
        self.label = label
        self.formValues = formValues
        self.systemPrompt = systemPrompt
        self.createdAt = Date()
        self.tabGroup = tabGroup
    }
}
