// What happens when the game starts: the configurations are read, once, before
// anything else. Four interface requirements are written as "when the game starts,
// the system shall read…", so this is the moment they name.
//
// A configuration that cannot be read stops the launch visibly rather than leaving
// the game running on numbers nobody chose. What the game should *show* in that case
// is not something the specification settles yet; what it must not do — carry on with
// defaults — it does settle, by ADR-0012's rule that a typo is an error.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-MAP-020, FR-MAP-160, FR-TOOL-200, FR-MAP-120, FR-MAP-140, IF-GREENHOLM-010
import Foundation

/// Everything a match runs on, read once at start: the tuning, the kit, the map as
/// parsed, the setting it names, the graph the bots path over and the geometry the
/// player sees. Assembled in one place so that the scene and the graph cannot come
/// from different files.
struct World {
    let configurations: Configurations
    let kit: Kit
    let map: MapSpecification
    /// The world the arena stands in (FR-MAP-120). Scenery only: nothing below reads
    /// it but the view (FR-MAP-130).
    let setting: Setting
    let graph: NavigationGraph
    let plan: ScenePlan
}

enum Launch {
    /// Reads everything the game starts on: the configurations, then the kit the map
    /// names, then the map itself, then what is derived from them.
    static func world(from bundle: Bundle = .main,
                      map name: String = Resource.startingMap) -> Result<World, Error> {
        do {
            let configurations = try Configurations.load(from: bundle)
            guard let url = bundle.url(forResource: name, withExtension: Resource.mapExtension,
                                       subdirectory: Resource.mapDirectory) else {
                throw MapLoadError.missing(name: name)
            }
            let text: String
            do { text = try String(contentsOf: url, encoding: .utf8) }
            catch { throw MapLoadError.unreadable(name: name, underlying: error) }
            // The kit is read first because the map cannot be read without it: which
            // characters are legal is the kit's legend (ADR-0012).
            let header = try MapParser.kitName(in: text)
            let kit = try Kit.load(named: header, from: bundle)
            let map = try MapParser.parse(text, kit: kit, stepHeight: configurations.tuning.stepHeight)
            let setting = try Setting.load(named: map.setting, from: bundle)
            // A camera that could see the horizon could see past any world a setting
            // builds (FR-MAP-140); that is a configuration no match can run on.
            try FrameCoverage.requireGroundInFrame(view: configurations.view)
            return .success(World(configurations: configurations,
                                  kit: kit,
                                  map: map,
                                  setting: setting,
                                  graph: NavigationGraph.derive(from: map, stepHeight: configurations.tuning.stepHeight),
                                  plan: ScenePlan.make(map: map, kit: kit,
                                                       cellSize: configurations.tuning.navigationGraphCellSize)))
        } catch {
            return .failure(error)
        }
    }

    /// Reads every configuration the game needs, in the order a reader would expect
    /// to hear about a failure: the first file that is wrong is the one reported.
    static func load(from bundle: Bundle = .main) -> Result<Configurations, ConfigurationError> {
        do {
            return .success(try Configurations.load(from: bundle))
        } catch let error as ConfigurationError {
            return .failure(error)
        } catch {
            // Configurations.load throws nothing else; this keeps that a fact rather
            // than an assumption, and says so if it ever stops being true.
            return .failure(.undecodable(name: Resource.unknownConfiguration, underlying: error))
        }
    }
}


enum MapLoadError: IdentifiedError, Equatable {
    case missing(name: String)
    /// The file is there and could not be read as UTF-8 text. The system's own error is
    /// carried in the details, so that the line still opens with a kind of this game's
    /// rather than with whatever the system called it (FR-TOOL-200).
    case unreadable(name: String, underlying: Error)

    var identifier: ErrorIdentifier {
        switch self {
        case .missing:    return .mapMissing
        case .unreadable: return .mapUnreadable
        }
    }

    var details: String {
        switch self {
        case .missing(let n):          return "\(Resource.mapFile(n)) is missing from the bundle"
        case .unreadable(let n, let e): return "\(Resource.mapFile(n)) could not be read as UTF-8 text: \(e)"
        }
    }

    /// Two failures are the same when they are of one kind about one map; the system's
    /// error inside `unreadable` is evidence for a person, not part of what failed.
    static func == (a: MapLoadError, b: MapLoadError) -> Bool {
        switch (a, b) {
        case let (.missing(x), .missing(y)):             return x == y
        case let (.unreadable(x, _), .unreadable(y, _)): return x == y
        default:                                         return false
        }
    }
}
