import Foundation

/// Simple JSONPath extraction matching the web app's proxy.py behavior.
/// Supports:
///   $.foo.bar          — dot notation
///   $..key             — recursive descent (first match)
///   $.foo[0].bar       — array index
///   $.foo[*].bar       — array wildcard
enum JSONPath {

    /// Extract a value from a Foundation object using a JSONPath string.
    static func extract(from data: Any?, path: String?) -> Any? {
        guard let data, let path, !path.isEmpty else { return nil }

        var cleaned = path
        if cleaned.hasPrefix("$") {
            cleaned = String(cleaned.dropFirst())
        }

        // Recursive descent: $..key
        if cleaned.hasPrefix("..") {
            let remainder = String(cleaned.dropFirst(2))
            let key: String
            if let dotPart = remainder.split(separator: ".").first {
                key = String(dotPart)
            } else if let bracketPart = remainder.split(separator: "[").first {
                key = String(bracketPart)
            } else {
                key = remainder
            }
            return recursiveFind(data: data, key: key)
        }

        let parts = parsePathParts(cleaned)
        return walk(data: data, parts: parts)
    }

    /// Extract and return as JSONValue.
    static func extractValue(from data: Any?, path: String?) -> JSONValue? {
        guard let result = extract(from: data, path: path) else { return nil }
        return JSONValue.from(result)
    }

    // MARK: - Internal

    private static func recursiveFind(data: Any, key: String) -> Any? {
        if let dict = data as? [String: Any] {
            if let value = dict[key] {
                return value
            }
            for (_, v) in dict {
                if let result = recursiveFind(data: v, key: key) {
                    return result
                }
            }
        } else if let array = data as? [Any] {
            var results: [Any] = []
            for item in array {
                if let result = recursiveFind(data: item, key: key) {
                    if let arr = result as? [Any] {
                        results.append(contentsOf: arr)
                    } else {
                        results.append(result)
                    }
                }
            }
            return results.isEmpty ? nil : results
        }
        return nil
    }

    private static func parsePathParts(_ path: String) -> [String] {
        var parts: [String] = []
        let segments = path.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .split(separator: ".", omittingEmptySubsequences: true)

        for segment in segments {
            let s = String(segment)
            // Handle foo[0] or foo[*]
            if let match = s.range(of: #"^(\w+)\[(\*|\d+)\]$"#, options: .regularExpression) {
                let full = String(s[match])
                let bracketIdx = full.firstIndex(of: "[")!
                let name = String(full[full.startIndex..<bracketIdx])
                let idx = String(full[full.index(after: bracketIdx)..<full.index(before: full.endIndex)])
                parts.append(name)
                parts.append("[\(idx)]")
            } else {
                parts.append(s)
            }
        }
        return parts
    }

    private static func walk(data: Any?, parts: [String]) -> Any? {
        var current: Any? = data
        var i = 0
        while i < parts.count {
            guard let cur = current else { return nil }
            let part = parts[i]

            if part == "[*]" {
                guard let array = cur as? [Any] else { return nil }
                let remaining = Array(parts[(i + 1)...])
                return array.compactMap { walk(data: $0, parts: remaining) }
            } else if part.hasPrefix("[") && part.hasSuffix("]") {
                let idxStr = String(part.dropFirst().dropLast())
                guard let idx = Int(idxStr), let array = cur as? [Any], idx < array.count else {
                    return nil
                }
                current = array[idx]
            } else if let dict = cur as? [String: Any] {
                current = dict[part]
            } else {
                return nil
            }
            i += 1
        }
        return current
    }
}
