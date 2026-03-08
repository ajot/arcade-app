import Foundation

struct Bookmark: Codable, Identifiable {
    let id: UUID
    let definitionId: String
    let model: String?
    let label: String
    let formValues: [String: String]
    let systemPrompt: String
    let createdAt: Date

    init(
        definitionId: String,
        model: String?,
        label: String,
        formValues: [String: String],
        systemPrompt: String
    ) {
        self.id = UUID()
        self.definitionId = definitionId
        self.model = model
        self.label = label
        self.formValues = formValues
        self.systemPrompt = systemPrompt
        self.createdAt = Date()
    }
}
