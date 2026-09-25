// The world a map's arena stands in (FR-MAP-120): named by the map, provided by the
// game, drawn as scenery that takes no part in play (FR-MAP-130). Each setting is a
// family of its own, with a proper name and a configuration under
// `config/setting/`, so that a new one is added beside the others and changes none of
// them (ADR-0031).
//
// implements: FR-MAP-120, FR-MAP-130, IF-GREENHOLM-010, FR-TOOL-200
import Foundation

/// A setting the game provides, with what it was configured with.
enum Setting: Equatable {
    case greenholm(GreenholmConfiguration)

    /// The settings the game provides, by the names a map calls them.
    enum Name: String, CaseIterable {
        case greenholm
    }

    /// The setting a map names, with its configuration read from the bundle.
    static func load(named name: String, from bundle: Bundle) throws -> Setting {
        guard let known = Name(rawValue: name) else { throw SettingError.unknown(name: name) }
        switch known {
        case .greenholm:
            return .greenholm(try read(GreenholmConfiguration.self, known, GreenholmConfiguration.schema, bundle))
        }
    }

    private static func read<T: Decodable>(_ type: T.Type, _ name: Name,
                                           _ schema: Schema, _ bundle: Bundle) throws -> T {
        let named = Resource.setting(named: name.rawValue)
        guard let url = bundle.url(forResource: name.rawValue, withExtension: Resource.configurationExtension,
                                   subdirectory: Resource.settingsDirectory),
              let data = try? Data(contentsOf: url) else {
            throw ConfigurationError.fileMissing(name: named)
        }
        return try Configurations.decode(type, named: named, schema: schema, from: data)
    }

    /// The scenery the setting draws around an arena, for a camera that can take any
    /// of the range given (FR-MAP-140).
    func scenery(around plan: ScenePlan, camera: CameraRange) throws -> Scenery {
        switch self {
        case .greenholm(let configuration):
            return try Greenholm.scenery(around: plan, camera: camera, configuration: configuration)
        }
    }
}

enum SettingError: IdentifiedError, Equatable {
    /// The map names a setting the game does not provide.
    case unknown(name: String)

    var identifier: ErrorIdentifier { .settingUnknown }

    var details: String {
        switch self {
        case .unknown(let n):
            let known = Setting.Name.allCases.map(\.rawValue).joined(separator: MapFormat.listSeparator)
            return "the map names the setting '\(n)', and the game provides \(known)"
        }
    }
}
