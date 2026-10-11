// Strict shape checking for configuration files.
//
// ADR-0012: "a file with an unknown key is rejected at load, so that a typo in a
// tuning name is an error and not a silent default". `JSONDecoder` cannot do this —
// it ignores keys it does not know — so the shape is declared separately and walked
// before decoding. Standard library only (ART-040).
//
// file implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-TOOL-200
import Foundation

/// The shape a configuration file must have: which keys exist, and where a caller
/// may use names of its own (one entry per archetype, per module type, and so on).
indirect enum Schema {
    /// A leaf the decoder will type-check: a number, a string, a bool.
    case value
    /// An object with exactly these keys — no more, no fewer.
    case object([String: Schema])
    /// An object whose keys are names the configuration chooses, each of this shape.
    case named(of: Schema)
    /// An array of elements of this shape.
    case array(of: Schema)
}

enum SchemaError: IdentifiedError, Equatable {
    case notAnObject(path: String)
    case unknownKey(String, path: String)
    case missingKey(String, path: String)
    case wrongKind(path: String, expected: String)

    var identifier: ErrorIdentifier {
        switch self {
        case .notAnObject: return .schemaNotAnObject
        case .unknownKey:  return .schemaUnknownKey
        case .missingKey:  return .schemaMissingKey
        case .wrongKind:   return .schemaWrongKind
        }
    }

    var details: String {
        switch self {
        case .notAnObject(let p):           return "\(Self.where_(p)): expected an object"
        case .unknownKey(let k, let p):     return "\(Self.where_(p)): unknown key '\(k)'"
        case .missingKey(let k, let p):     return "\(Self.where_(p)): missing key '\(k)'"
        case .wrongKind(let p, let e):      return "\(Self.where_(p)): expected \(e)"
        }
    }

    private static func where_(_ path: String) -> String { path.isEmpty ? "the file" : path }
}

extension Schema {
    /// Walks a parsed JSON value against this shape, naming the first thing that is wrong.
    /// An unknown key is an error before anything is decoded, which is the whole point.
    func check(_ json: Any, at path: String = "") throws {
        switch self {
        case .value:
            return
        case .object(let fields):
            guard let dict = json as? [String: Any] else { throw SchemaError.notAnObject(path: path) }
            for key in dict.keys where fields[key] == nil {
                throw SchemaError.unknownKey(key, path: path)
            }
            for (key, sub) in fields {
                guard let value = dict[key] else { throw SchemaError.missingKey(key, path: path) }
                try sub.check(value, at: path.isEmpty ? key : "\(path).\(key)")
            }
        case .named(let sub):
            guard let dict = json as? [String: Any] else { throw SchemaError.notAnObject(path: path) }
            for (key, value) in dict {
                try sub.check(value, at: path.isEmpty ? key : "\(path).\(key)")
            }
        case .array(let sub):
            guard let items = json as? [Any] else { throw SchemaError.wrongKind(path: path, expected: "an array") }
            for (index, value) in items.enumerated() {
                try sub.check(value, at: "\(path)[\(index)]")
            }
        }
    }
}
