import Foundation

/// Handles all HTTP communication with AI provider APIs.
/// Supports sync, streaming (SSE), and polling interaction patterns.
@Observable
final class NetworkService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Sync Request

    /// Send a synchronous (one-shot) request and return the parsed response.
    func sendSync(
        definition: Definition,
        params: [String: String],
        apiKey: String
    ) async throws -> GenerationResult {
        let start = CFAbsoluteTimeGetCurrent()
        var built = try RequestBuilder.buildRequest(
            definition: definition, params: params, apiKey: apiKey
        )

        // Override stream to false for sync calls on streaming definitions
        if var body = built.body, body["stream"] as? Bool == true {
            body["stream"] = false
            built = RequestBuilder.BuiltRequest(
                url: built.url, method: built.method, headers: built.headers, body: body
            )
        }

        let request = makeURLRequest(from: built)
        let (data, response) = try await session.data(for: request)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Handle binary audio responses (TTS endpoints)
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        if httpResponse.statusCode == 200 &&
            (contentType.contains("audio") || contentType.contains("octet-stream")) {
            let base64 = data.base64EncodedString()
            let mime = contentType.split(separator: ";").first.map(String.init) ?? "audio/wav"
            let dataURL = "data:\(mime);base64,\(base64)"
            let responseData: [String: Any] = ["audio_url": dataURL]
            let outputs = extractOutputs(definition: definition, responseData: responseData)
            return GenerationResult(
                outputs: outputs,
                rawResponse: responseData,
                statusCode: httpResponse.statusCode,
                duration: elapsed
            )
        }

        guard let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.nonJSONResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = extractError(definition: definition, responseData: responseData)
                ?? "HTTP \(httpResponse.statusCode)"
            throw NetworkError.providerError(errorMsg)
        }

        let outputs = extractOutputs(definition: definition, responseData: responseData)
        return GenerationResult(
            outputs: outputs,
            rawResponse: responseData,
            statusCode: httpResponse.statusCode,
            duration: elapsed
        )
    }

    // MARK: - Streaming Request (SSE)

    /// Stream tokens from an SSE endpoint, calling the handler for each token.
    func sendStreaming(
        definition: Definition,
        params: [String: String],
        apiKey: String,
        onToken: @escaping (String) -> Void
    ) async throws -> StreamingResult {
        let start = CFAbsoluteTimeGetCurrent()
        let built = try RequestBuilder.buildRequest(
            definition: definition, params: params, apiKey: apiKey
        )

        let request = makeURLRequest(from: built)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.providerError(errorString)
        }

        let streamPath = definition.interaction.streamPath
        var tokenCount = 0
        var firstTokenTime: Double?

        for try await line in bytes.lines {
            guard !Task.isCancelled else { break }

            if line.hasPrefix("data: ") {
                let chunkStr = String(line.dropFirst(6))
                if chunkStr.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                    break
                }

                guard let chunkData = chunkStr.data(using: .utf8),
                      let chunk = try? JSONSerialization.jsonObject(with: chunkData) else {
                    continue
                }

                if let token = JSONPath.extract(from: chunk, path: streamPath) as? String,
                   !token.isEmpty {
                    if firstTokenTime == nil {
                        firstTokenTime = CFAbsoluteTimeGetCurrent() - start
                    }
                    tokenCount += 1
                    onToken(token)
                }
            }
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - start
        return StreamingResult(
            tokenCount: tokenCount,
            firstTokenTime: firstTokenTime,
            totalDuration: totalDuration,
            tokensPerSecond: totalDuration > 0 ? Double(tokenCount) / totalDuration : 0
        )
    }

    // MARK: - Polling Request

    /// Submit an async job and poll until completion.
    func sendPolling(
        definition: Definition,
        params: [String: String],
        apiKey: String,
        onStatusUpdate: @escaping (String) -> Void
    ) async throws -> GenerationResult {
        let start = CFAbsoluteTimeGetCurrent()
        let built = try RequestBuilder.buildRequest(
            definition: definition, params: params, apiKey: apiKey
        )

        // Submit the initial request
        let submitRequest = makeURLRequest(from: built)
        let (submitData, submitResponse) = try await session.data(for: submitRequest)

        guard let httpResponse = submitResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let statusCode = (submitResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw NetworkError.providerError("Submit failed with HTTP \(statusCode)")
        }

        guard let submitJson = try? JSONSerialization.jsonObject(with: submitData) as? [String: Any] else {
            throw NetworkError.nonJSONResponse
        }

        // Extract request ID
        let requestIdPath = definition.interaction.requestIdPath ?? "$.request_id"
        guard let requestId = JSONPath.extract(from: submitJson, path: requestIdPath) as? String else {
            // Some APIs return the ID as a number
            if let numId = JSONPath.extract(from: submitJson, path: requestIdPath) {
                let requestId = "\(numId)"
                return try await pollForResult(
                    definition: definition, requestId: requestId, apiKey: apiKey,
                    start: start, onStatusUpdate: onStatusUpdate
                )
            }
            throw NetworkError.missingRequestId
        }

        return try await pollForResult(
            definition: definition, requestId: requestId, apiKey: apiKey,
            start: start, onStatusUpdate: onStatusUpdate
        )
    }

    private func pollForResult(
        definition: Definition,
        requestId: String,
        apiKey: String,
        start: Double,
        onStatusUpdate: @escaping (String) -> Void
    ) async throws -> GenerationResult {
        let pollInterval = definition.interaction.pollIntervalMs ?? 2000
        let auth = definition.auth
        var pollCount = 0

        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(pollInterval))
            pollCount += 1
            onStatusUpdate("Polling... (\(pollCount))")

            // Check status
            guard let statusURL = RequestBuilder.buildStatusURL(
                definition: definition, requestId: requestId
            ) else {
                throw NetworkError.invalidResponse
            }

            var statusReq = URLRequest(url: statusURL)
            if auth.type == "header" {
                let key = KeychainService.getKey(for: definition.provider) ?? ""
                statusReq.setValue("\(auth.prefix)\(key)", forHTTPHeaderField: auth.header)
            }

            let (statusData, _) = try await session.data(for: statusReq)
            guard let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any] else {
                continue
            }

            let pollStatus = checkDone(definition: definition, statusResponse: statusJson)

            switch pollStatus {
            case .done:
                // Fetch final result
                guard let resultURL = RequestBuilder.buildResultURL(
                    definition: definition, requestId: requestId
                ) else {
                    throw NetworkError.invalidResponse
                }

                var resultReq = URLRequest(url: resultURL)
                if auth.type == "header" {
                    let key = KeychainService.getKey(for: definition.provider) ?? ""
                    resultReq.setValue("\(auth.prefix)\(key)", forHTTPHeaderField: auth.header)
                }

                let (resultData, _) = try await session.data(for: resultReq)
                guard let resultJson = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
                    throw NetworkError.nonJSONResponse
                }

                let outputs = extractOutputs(definition: definition, responseData: resultJson)
                let elapsed = CFAbsoluteTimeGetCurrent() - start

                return GenerationResult(
                    outputs: outputs,
                    rawResponse: resultJson,
                    statusCode: 200,
                    duration: elapsed,
                    pollCount: pollCount
                )

            case .failed:
                let errorMsg = extractError(definition: definition, responseData: statusJson)
                    ?? "Job failed"
                throw NetworkError.providerError(errorMsg)

            case .pending:
                continue
            }
        }

        throw CancellationError()
    }

    // MARK: - Response Extraction

    private func extractOutputs(definition: Definition, responseData: [String: Any]) -> [ExtractedOutput] {
        var outputs: [ExtractedOutput] = []

        for outputDef in definition.response.outputs {
            guard let value = JSONPath.extract(from: responseData, path: outputDef.path) else {
                continue
            }

            let values: [Any] = (value as? [Any]) ?? [value]
            var stringValues = values.map { val -> String in
                if let s = val as? String { return s }
                if let n = val as? NSNumber { return n.stringValue }
                return "\(val)"
            }

            // Convert base64 to data URLs
            if outputDef.source == .base64 && (outputDef.type == .image || outputDef.type == .audio) {
                let mime = outputDef.mimeType
                    ?? (outputDef.type == .image ? "image/png" : "audio/wav")
                stringValues = stringValues.map { val in
                    val.hasPrefix("data:") ? val : "data:\(mime);base64,\(val)"
                }
            }

            outputs.append(ExtractedOutput(
                type: outputDef.type,
                source: outputDef.source,
                values: stringValues,
                downloadable: outputDef.downloadable ?? false
            ))
        }

        return outputs
    }

    private func extractError(definition: Definition, responseData: [String: Any]) -> String? {
        let errorPath = definition.response.error.path
        if let error = JSONPath.extract(from: responseData, path: errorPath) {
            if let s = error as? String { return s }
            return "\(error)"
        }
        return nil
    }

    private enum PollStatus { case done, failed, pending }

    private func checkDone(definition: Definition, statusResponse: [String: Any]) -> PollStatus {
        if let doneWhen = definition.interaction.doneWhen {
            if let val = JSONPath.extract(from: statusResponse, path: doneWhen.path) as? String {
                if let eq = doneWhen.equals, val == eq { return .done }
                if let vals = doneWhen.inValues, vals.contains(val) { return .done }
            }
        }

        if let failedWhen = definition.interaction.failedWhen {
            if let val = JSONPath.extract(from: statusResponse, path: failedWhen.path) as? String {
                if let eq = failedWhen.equals, val == eq { return .failed }
                if let vals = failedWhen.inValues, vals.contains(val) { return .failed }
            }
        }

        return .pending
    }

    // MARK: - Helpers

    private func makeURLRequest(from built: RequestBuilder.BuiltRequest) -> URLRequest {
        var request = URLRequest(url: built.url)
        request.httpMethod = built.method
        for (key, value) in built.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body = built.body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return request
    }
}

// MARK: - Result Types

struct GenerationResult: Sendable {
    let outputs: [ExtractedOutput]
    let rawResponse: [String: Any]
    let statusCode: Int
    let duration: Double
    var pollCount: Int = 0

    // Sendable conformance for rawResponse
    init(outputs: [ExtractedOutput], rawResponse: [String: Any], statusCode: Int, duration: Double, pollCount: Int = 0) {
        self.outputs = outputs
        self.rawResponse = rawResponse
        self.statusCode = statusCode
        self.duration = duration
        self.pollCount = pollCount
    }
}

struct StreamingResult: Sendable {
    let tokenCount: Int
    let firstTokenTime: Double?
    let totalDuration: Double
    let tokensPerSecond: Double
}

struct ExtractedOutput: Sendable, Identifiable {
    let id = UUID()
    let type: OutputType
    let source: OutputSource
    let values: [String]
    let downloadable: Bool
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case nonJSONResponse
    case providerError(String)
    case missingRequestId

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .nonJSONResponse: return "Non-JSON response from provider"
        case .providerError(let msg): return msg
        case .missingRequestId: return "Could not extract request ID for polling"
        }
    }
}
