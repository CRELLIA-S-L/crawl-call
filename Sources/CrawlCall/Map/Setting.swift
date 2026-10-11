// The world a map's arena stands in (FR-MAP-120): named by the map, provided by the
// game, drawn as scenery that takes no part in play (FR-MAP-130). Each setting is a
// family of its own, with a proper name and a configuration under
// `config/setting/`, so that a new one is added beside the others and changes none of
// them (ADR-0031).
//
// file implements: FR-MAP-120, FR-MAP-200, IF-GREENHOLM-010, FR-TOOL-200, FR-MAP-260
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

    /// The setting's edge round a plan's ground floor (FR-MAP-200), as the drawing
    /// makes it; nil where there is no ground floor.
    ///
    /// Computed here rather than asked of the setting's scenery: the edge is what play
    /// reads — the passage check asks it where the ground ends — and the scenery is what
    /// play may not read at all (FR-MAP-130, ADR-0073).
    func edge(around plan: ScenePlan) -> Outline? {
        switch self {
        // Greenholm's edge: the ground floor's cells are the island, and the cells of
        // floors below it are basements, which the island's ground leaves open to be
        // seen into.
        case .greenholm(let c):
            guard let groundLevel = plan.groundLevel else { return nil }
            return Outline.around(plan.cells { $0 == groundLevel }, basement: plan.cells { $0 < groundLevel },
                                  cellSize: plan.cellSize, margin: c.edgeMargin, rounding: c.edgeRounding,
                                  reach: c.shoreWidth + max(c.foamWidth, .zero) + max(c.floorWidth, .zero)
                                      + OutlineGrid.pad)
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
