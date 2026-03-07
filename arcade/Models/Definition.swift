import Foundation

// MARK: - Definition

struct Definition: Codable, Identifiable, Sendable {
    let schemaVersion: Int
    let id: String
    let provider: String
    let providerDisplayName: String
    let providerUrl: String
    let name: String
    let description: String
    let auth: AuthConfig
    let request: RequestConfig
    let interaction: InteractionConfig
    let examples: [Example]
    let response: ResponseConfig

    /// The primary output type (text, image, audio, video).
    var outputType: OutputType {
        response.outputs.first?.type ?? .text
    }

    /// The model parameter definition, if one exists.
    var modelParam: ParamDefinition? {
        request.params.first { $0.name == "model" }
    }

    /// Number of available models.
    var modelCount: Int {
        modelParam?.options?.count ?? 0
    }

    /// Default model name.
    var defaultModel: String? {
        modelParam?.defaultValue?.stringValue
    }

    /// Whether this definition uses the chat message pattern.
    var isChatEndpoint: Bool {
        request.params.contains { $0.bodyPath == "_chat_message" }
    }

    /// Regular (non-advanced) parameters, excluding model.
    var regularParams: [ParamDefinition] {
        request.params.filter { $0.group == nil && $0.name != "model" }
    }

    /// Advanced parameters (group == "advanced").
    var advancedParams: [ParamDefinition] {
        request.params.filter { $0.group == "advanced" }
    }
}

// MARK: - Auth

struct AuthConfig: Codable, Sendable {
    let type: String
    let header: String
    let prefix: String
    let envKey: String
    let validationUrl: String?
}

// MARK: - Request

struct RequestConfig: Codable, Sendable {
    let method: String
    let url: String
    let contentType: String
    let bodyTemplate: JSONValue
    let params: [ParamDefinition]
}

// MARK: - Param

struct ParamDefinition: Codable, Identifiable, Sendable {
    let name: String
    let type: ParamType
    let required: Bool?
    let ui: ParamUIType
    let placeholder: String?
    let group: String?
    let min: Double?
    let max: Double?
    let defaultValue: JSONValue?
    let options: [String]?
    let bodyPath: String?
    let urlPath: Bool?

    var id: String { name }

    var isRequired: Bool { required ?? false }

    /// The default as a display string.
    var defaultDisplayString: String? {
        guard let dv = defaultValue else { return nil }
        switch dv {
        case .string(let s): return s
        case .int(let i): return "\(i)"
        case .double(let d): return String(format: d.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, type, required, ui, placeholder, group
        case min, max, options, bodyPath, urlPath
        case defaultValue = "default"
    }
}

enum ParamType: String, Codable, Sendable {
    case `enum`
    case string
    case integer
    case float
}

enum ParamUIType: String, Codable, Sendable {
    case dropdown
    case textarea
    case slider
    case text
}

// MARK: - Interaction

struct InteractionConfig: Codable, Sendable {
    let pattern: InteractionPattern
    let streamFormat: String?
    let streamPath: String?
    let responseType: String?
    let statusUrl: String?
    let resultUrl: String?
    let requestIdPath: String?
    let pollIntervalMs: Int?
    let doneWhen: PollingCondition?
    let failedWhen: PollingCondition?
}

enum InteractionPattern: String, Codable, Sendable {
    case sync
    case streaming
    case polling
}

struct PollingCondition: Codable, Sendable {
    let path: String
    let equals: String?
    let inValues: [String]?

    private enum CodingKeys: String, CodingKey {
        case path, equals
        case inValues = "in"
    }
}

// MARK: - Response

struct ResponseConfig: Codable, Sendable {
    let outputs: [ResponseOutput]
    let error: ErrorConfig
}

struct ResponseOutput: Codable, Sendable {
    let path: String
    let type: OutputType
    let source: OutputSource
    let downloadable: Bool?
    let mimeType: String?
}

enum OutputType: String, Codable, Sendable {
    case text
    case image
    case audio
    case video
}

enum OutputSource: String, Codable, Sendable {
    case inline
    case url
    case base64
}

struct ErrorConfig: Codable, Sendable {
    let path: String
}

// MARK: - Example

struct Example: Codable, Identifiable, Sendable {
    let label: String
    let params: [String: JSONValue]

    var id: String { label }
}
