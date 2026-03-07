import Foundation

/// A type-erased JSON value that can represent any JSON structure.
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode JSONValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    // MARK: - Accessors

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    /// Convert to Foundation type for JSON serialization.
    var toFoundation: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .array(let v): return v.map(\.toFoundation)
        case .object(let v): return v.mapValues(\.toFoundation)
        case .null: return NSNull()
        }
    }

    /// Create from a Foundation object.
    static func from(_ value: Any) -> JSONValue {
        switch value {
        case let s as String: return .string(s)
        case let b as Bool: return .bool(b)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let a as [Any]: return .array(a.map { from($0) })
        case let o as [String: Any]: return .object(o.mapValues { from($0) })
        default: return .null
        }
    }

    // MARK: - Mutation helpers for building request bodies

    /// Set a value at a dot-separated path (e.g. "input.prompt" or "instances.0.prompt").
    mutating func setNested(path: String, value: JSONValue) {
        let keys = path.split(separator: ".").map(String.init)
        setNested(keys: keys, value: value)
    }

    private mutating func setNested(keys: [String], value: JSONValue) {
        guard let first = keys.first else { return }

        if keys.count == 1 {
            if let idx = Int(first), case .array(var arr) = self, idx < arr.count {
                arr[idx] = value
                self = .array(arr)
            } else if case .object(var obj) = self {
                obj[first] = value
                self = .object(obj)
            }
            return
        }

        let remaining = Array(keys.dropFirst())
        if let idx = Int(first), case .array(var arr) = self, idx < arr.count {
            arr[idx].setNested(keys: remaining, value: value)
            self = .array(arr)
        } else if case .object(var obj) = self {
            var child = obj[first] ?? .object([:])
            child.setNested(keys: remaining, value: value)
            obj[first] = child
            self = .object(obj)
        }
    }
}
