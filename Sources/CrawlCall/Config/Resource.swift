// Where the game's files are in its bundle (ADR-0012): the directories, the
// extensions and the names it asks for them by (ART-070).
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-MAP-010, FR-MAP-100
import Foundation

enum Resource {
    /// Configuration files are JSON, one per interface, under `config/`.
    static let configurationDirectory = "config"
    static let configurationExtension = "json"
    /// A module kit is a directory under `config/kit/` holding its legend.
    static let kitDirectory = "kit"
    static let legendName = "legend"
    /// Map files are text, under `maps/` (IF-MAP-010).
    static let mapDirectory = "maps"
    static let mapExtension = "map"
    /// The map a match is played on. Stage 1 has one (concept §13).
    static let startingMap = "blockout"
    /// How the parts of a path inside the bundle are joined.
    static let pathSeparator = "/"
    /// How a file's name and its extension are joined.
    static let extensionSeparator = "."

    /// The configuration files the game reads at start, by the names their files have.
    enum Configuration: String {
        case snake, tuning, view, bot, match
    }

    /// What a configuration failure names when the file it came from is not known.
    static let unknownConfiguration = "unknown"

    static func path(_ parts: String...) -> String { parts.joined(separator: pathSeparator) }
    static func file(_ name: String, _ ext: String) -> String { name + extensionSeparator + ext }

    /// `config/<name>.json`, as a message names it.
    static func configurationFile(_ name: String) -> String {
        path(configurationDirectory, file(name, configurationExtension))
    }

    /// `kit/<name>/legend`: a kit's legend, named as a configuration relative to `config/`.
    static func legend(ofKit name: String) -> String { path(kitDirectory, name, legendName) }

    /// `config/kit/<name>`: the directory a kit's legend is in.
    static func kitDirectory(_ name: String) -> String { path(configurationDirectory, kitDirectory, name) }

    /// `maps/<name>.map`, as a message names it.
    static func mapFile(_ name: String) -> String { path(mapDirectory, file(name, mapExtension)) }
}
