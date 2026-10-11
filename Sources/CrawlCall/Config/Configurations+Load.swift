// Reading the configuration files. Paths are relative to the application bundle in
// the game and to the repository root in the tools (ADR-0012); this is the game half.
//
// file implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-SCORE-010, FR-TOOL-200
import Foundation

enum ConfigurationError: IdentifiedError {
    case fileMissing(name: String)
    case notJSON(name: String, underlying: Error)
    case badShape(name: String, error: SchemaError)
    case undecodable(name: String, underlying: Error)

    var identifier: ErrorIdentifier {
        switch self {
        case .fileMissing: return .configFileMissing
        case .notJSON:     return .configNotJSON
        case .badShape:    return .configBadShape
        case .undecodable: return .configUndecodable
        }
    }

    var details: String {
        switch self {
        case .fileMissing(let n):          return "\(Resource.configurationFile(n)) is missing from the bundle"
        case .notJSON(let n, let e):       return "\(Resource.configurationFile(n)) is not JSON: \(e)"
        case .badShape(let n, let e):      return "\(Resource.configurationFile(n)) — \(e)"
        case .undecodable(let n, let e):   return "\(Resource.configurationFile(n)) does not decode: \(e)"
        }
    }
}

/// Everything the game reads at start, in one value, so that a missing or malformed
/// file stops the launch instead of surfacing as a wrong number an hour later.
struct Configurations {
    let snake: SnakeConfiguration
    let tuning: TuningConfiguration
    let view: ViewConfiguration
    let bot: BotConfiguration
    let match: MatchConfiguration
    let scoring: ScoringConfiguration

    static func load(from bundle: Bundle) throws -> Configurations {
        Configurations(
            snake:  try read(SnakeConfiguration.self,  .snake,  SnakeConfiguration.schema,  bundle),
            tuning: try read(TuningConfiguration.self, .tuning, TuningConfiguration.schema, bundle),
            view:   try read(ViewConfiguration.self,   .view,   ViewConfiguration.schema,   bundle),
            bot:    try read(BotConfiguration.self,    .bot,    BotConfiguration.schema,    bundle),
            match:  try read(MatchConfiguration.self,  .match,  MatchConfiguration.schema,  bundle),
            scoring: try read(ScoringConfiguration.self, .scoring, ScoringConfiguration.schema, bundle))
    }

    private static func read<T: Decodable>(_ type: T.Type, _ file: Resource.Configuration,
                                           _ schema: Schema, _ bundle: Bundle) throws -> T {
        let name = file.rawValue
        guard let url = bundle.url(forResource: name, withExtension: Resource.configurationExtension,
                                   subdirectory: Resource.configurationDirectory),
              let data = try? Data(contentsOf: url) else {
            throw ConfigurationError.fileMissing(name: name)
        }
        return try decode(type, named: name, schema: schema, from: data)
    }

    /// The same path a file from the bundle takes, exposed so that a test can hand it
    /// bytes directly — the shape check is the behaviour worth testing, not the I/O.
    static func decode<T: Decodable>(_ type: T.Type, named name: String,
                                     schema: Schema, from data: Data) throws -> T {
        let json: Any
        do { json = try JSONSerialization.jsonObject(with: data) }
        catch { throw ConfigurationError.notJSON(name: name, underlying: error) }

        do { try schema.check(json) }
        catch let error as SchemaError { throw ConfigurationError.badShape(name: name, error: error) }

        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw ConfigurationError.undecodable(name: name, underlying: error) }
    }
}
