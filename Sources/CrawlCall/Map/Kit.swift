// A module kit: which character in a map file means which module, and what that
// module is. ADR-0012 puts the legend in `legend.json` beside the kit's modules so
// that a map and its kit cannot disagree.
//
// The kit also carries its floor height. No requirement names that number — a map
// file holds a kit, transitions and grids (IF-MAP-010), and the tuning configuration
// holds distances, not storeys (IF-MAP-020) — so it lives with the geometry it is a
// property of. Said out loud because the specification is silent on it.
//
// implements: FR-MAP-100, FR-TOOL-200, FR-MAP-150
import Foundation

struct Kit: Decodable, Equatable {
    struct Module: Decodable, Equatable {
        let name: String
        let walkable: Bool
        /// Width, height and depth in metres; a floor module is a thin slab.
        let size: [Double]
        /// Red, green and blue in 0…1. In the kit rather than in code because it is
        /// what the module looks like, and a kit is what a map is assembled from
        /// (FR-MAP-100).
        let colour: [Double]
    }

    /// Metres from one floor's walking surface to the next.
    let floorHeight: Double
    /// The character of the module that is this kit's floor. A cell holds one module
    /// (IF-MAP-010), so the floor under a wall is placed from here (FR-TOOL-020).
    let floorModule: String
    /// The character of the module a step of a flight of stairs is drawn as. A map
    /// draws a step as an arrow, not as this character, because which way a flight
    /// rises is the map's to say (IF-MAP-010); the kit says what a step looks like and
    /// how wide it is, and its height is the flight's (FR-MAP-150, ADR-0033).
    let stepModule: String
    /// Keyed by the single character that names the module in a map grid.
    let modules: [String: Module]

    static let schema = Schema.object([
        "floorHeight": .value,
        "floorModule": .value,
        "stepModule": .value,
        "modules": .named(of: .object(["name": .value, "walkable": .value,
                                      "size": .array(of: .value), "colour": .array(of: .value)])),
    ])

    enum KitError: IdentifiedError, Equatable {
        case missing(name: String)
        case legendKeyIsNotOneCharacter(String)
        case moduleFieldIsNotThreeNumbers(module: String, field: String)
        case stepModuleNotInLegend(String)

        var identifier: ErrorIdentifier {
            switch self {
            case .missing:                      return .kitMissing
            case .legendKeyIsNotOneCharacter:   return .kitLegendKeyNotOneCharacter
            case .moduleFieldIsNotThreeNumbers: return .kitModuleFieldNotThreeNumbers
            case .stepModuleNotInLegend:        return .kitStepModuleNotInLegend
            }
        }

        var details: String {
            switch self {
            case .missing(let n):
                return "\(Resource.configurationFile(Resource.legend(ofKit: n))) is missing from the bundle"
            case .legendKeyIsNotOneCharacter(let k):
                return "the legend key '\(k)' is not a single character; a grid cell is one character"
            case .moduleFieldIsNotThreeNumbers(let m, let f):
                return "module '\(m)' has a \(f) that is not three numbers"
            case .stepModuleNotInLegend(let k):
                return "the step module '\(k)' is not a key of the legend; a flight of stairs would have nothing to be drawn as"
            }
        }
    }

    static func load(named name: String, from bundle: Bundle) throws -> Kit {
        guard let url = bundle.url(forResource: Resource.legendName,
                                   withExtension: Resource.configurationExtension,
                                   subdirectory: Resource.kitDirectory(name)),
              let data = try? Data(contentsOf: url) else {
            throw KitError.missing(name: name)
        }
        let kit = try Configurations.decode(Kit.self, named: Resource.legend(ofKit: name),
                                            schema: Kit.schema, from: data)
        // A grid cell is one character, so a legend key that is not one character could
        // never be matched — an error at load rather than a module nobody can place.
        for key in kit.modules.keys where key.count != MapFormat.charactersPerCell {
            throw KitError.legendKeyIsNotOneCharacter(key)
        }
        guard kit.modules[kit.stepModule] != nil else { throw KitError.stepModuleNotInLegend(kit.stepModule) }
        for (key, module) in kit.modules {
            let named = "\(key) (\(module.name))"
            if module.size.count != SIMD3<Double>.scalarCount {
                throw KitError.moduleFieldIsNotThreeNumbers(module: named, field: MapFormat.moduleSize)
            }
            if module.colour.count != SIMD3<Double>.scalarCount {
                throw KitError.moduleFieldIsNotThreeNumbers(module: named, field: MapFormat.moduleColour)
            }
        }
        return kit
    }

    /// The module a grid character names, or nil if the kit does not know it.
    func module(for character: Character) -> Module? { modules[String(character)] }

    /// What a cell's module stands on, when the module is not the surface itself.
    var floor: Module? { modules[floorModule] }

    /// What a step of a flight is drawn as.
    var step: Module? { modules[stepModule] }
}
