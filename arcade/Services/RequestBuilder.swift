import Foundation

/// Builds HTTP requests from definitions and user-supplied parameters.
/// Direct port of proxy.py's build_request logic.
enum RequestBuilder {

    struct BuiltRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: [String: Any]?
    }

    /// Build a complete HTTP request from a definition and parameters.
    static func buildRequest(
        definition: Definition,
        params: [String: String],
        apiKey: String
    ) throws -> BuiltRequest {
        let req = definition.request

        // Headers
        var headers: [String: String] = [
            "Content-Type": req.contentType,
        ]
        let auth = definition.auth
        if auth.type == "header" {
            headers[auth.header] = "\(auth.prefix)\(apiKey)"
        }

        // Build body from template
        var bodyValue = req.bodyTemplate
        for param in req.params {
            guard let rawValue = params[param.name] else { continue }
            if param.urlPath == true { continue }

            let jsonVal = coerceValue(rawValue, type: param.type)

            if param.bodyPath == "_chat_message" {
                // Special: wrap as messages array
                bodyValue.setNested(path: "messages", value: .array([
                    .object([
                        "role": .string("user"),
                        "content": .string(rawValue),
                    ])
                ]))
            } else if let path = param.bodyPath {
                bodyValue.setNested(path: path, value: jsonVal)
            } else {
                // Direct body key
                if case .object(var obj) = bodyValue {
                    obj[param.name] = jsonVal
                    bodyValue = .object(obj)
                }
            }
        }

        // System prompt injection
        if let systemPrompt = params["_system_prompt"], !systemPrompt.isEmpty {
            if case .object(var obj) = bodyValue, let messages = obj["messages"]?.arrayValue {
                var newMessages = [JSONValue.object([
                    "role": .string("system"),
                    "content": .string(systemPrompt),
                ])]
                newMessages.append(contentsOf: messages)
                obj["messages"] = .array(newMessages)
                bodyValue = .object(obj)
            }
        }

        // URL path substitution (e.g., {model} in URL)
        var urlString = req.url
        for param in req.params where param.urlPath == true {
            if let value = params[param.name] {
                urlString = urlString.replacingOccurrences(of: "{\(param.name)}", with: value)
            }
        }

        // Debug: print the body being sent
        if let bodyData = try? JSONSerialization.data(
            withJSONObject: bodyValue.toFoundation,
            options: [.prettyPrinted, .sortedKeys]
        ), let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[Arcade] Request body: \(bodyString)")
        }

        guard let url = URL(string: urlString) else {
            throw BuildError.invalidURL(urlString)
        }

        let body = bodyValue.toFoundation as? [String: Any]
        return BuiltRequest(url: url, method: req.method, headers: headers, body: body)
    }

    /// Build a curl command string for preview.
    static func buildCurlString(
        definition: Definition,
        params: [String: String],
        includeKey: Bool,
        apiKey: String?
    ) -> String {
        let req = definition.request
        let effectiveKey = includeKey ? (apiKey ?? "<API_KEY>") : "<API_KEY>"

        var headers: [String: String] = [
            "Content-Type": req.contentType,
        ]
        let auth = definition.auth
        if auth.type == "header" {
            headers[auth.header] = "\(auth.prefix)\(effectiveKey)"
        }

        // Build body
        var bodyValue = req.bodyTemplate
        for param in req.params {
            guard let rawValue = params[param.name] else { continue }
            if param.urlPath == true { continue }

            let jsonVal = coerceValue(rawValue, type: param.type)

            if param.bodyPath == "_chat_message" {
                bodyValue.setNested(path: "messages", value: .array([
                    .object([
                        "role": .string("user"),
                        "content": .string(rawValue),
                    ])
                ]))
            } else if let path = param.bodyPath {
                bodyValue.setNested(path: path, value: jsonVal)
            } else {
                if case .object(var obj) = bodyValue {
                    obj[param.name] = jsonVal
                    bodyValue = .object(obj)
                }
            }
        }

        if let systemPrompt = params["_system_prompt"], !systemPrompt.isEmpty {
            if case .object(var obj) = bodyValue, let messages = obj["messages"]?.arrayValue {
                var newMessages = [JSONValue.object([
                    "role": .string("system"),
                    "content": .string(systemPrompt),
                ])]
                newMessages.append(contentsOf: messages)
                obj["messages"] = .array(newMessages)
                bodyValue = .object(obj)
            }
        }

        var urlString = req.url
        for param in req.params where param.urlPath == true {
            if let value = params[param.name] {
                urlString = urlString.replacingOccurrences(of: "{\(param.name)}", with: value)
            }
        }

        let method = req.method.uppercased()
        var parts = ["curl -X \(method) '\(urlString)'"]
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            parts.append("  -H '\(key): \(value)'")
        }

        if let bodyData = try? JSONSerialization.data(
            withJSONObject: bodyValue.toFoundation,
            options: [.prettyPrinted, .sortedKeys]
        ), let bodyString = String(data: bodyData, encoding: .utf8) {
            parts.append("  -d '\(bodyString)'")
        }

        return parts.joined(separator: " \\\n")
    }

    /// Build status URL for polling.
    static func buildStatusURL(definition: Definition, requestId: String) -> URL? {
        guard let template = definition.interaction.statusUrl else { return nil }
        let urlString = template.replacingOccurrences(of: "{request_id}", with: requestId)
        return URL(string: urlString)
    }

    /// Build result URL for polling.
    static func buildResultURL(definition: Definition, requestId: String) -> URL? {
        guard let template = definition.interaction.resultUrl else { return nil }
        let urlString = template.replacingOccurrences(of: "{request_id}", with: requestId)
        return URL(string: urlString)
    }

    // MARK: - Helpers

    private static func coerceValue(_ raw: String, type: ParamType) -> JSONValue {
        switch type {
        case .integer:
            return .int(Int(raw) ?? 0)
        case .float:
            return .double(Double(raw) ?? 0)
        case .enum, .string:
            return .string(raw)
        }
    }

    enum BuildError: LocalizedError {
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let url): return "Invalid URL: \(url)"
            }
        }
    }
}
