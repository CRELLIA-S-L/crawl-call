// The names the scene's entities are given and found by (ART-070). A name is how one
// part of the scene finds another — the match looks the camera up by it — so it is
// declared once and not spelled at each end.
//
// implements: FR-TOOL-020, FR-VIEW-020, FR-VIEW-100, FR-VIEW-170
import Foundation

enum EntityName {
    static let scene = "scene"
    static let map = "map"
    static let camera = "camera"
    static let ambient = "ambient"
    static let light = "light"
    static let snake = "snake"
    static let head = "head"
    static let segment = "segment"
    static let bots = "bots"
    static let bot = "bot"
    static let shots = "shots"
    static let shot = "shot"

    /// A tracer's name ends in the squad that fires it, so that a pool of them can be
    /// sorted by squad again without a table beside it.
    static let redSquadSuffix = "r"
    static let blueSquadSuffix = "b"

    /// `segment<index>`, `bot<id>`: one of many of a kind, by its number.
    static func numbered(_ kind: String, _ number: Int) -> String { kind + String(number) }
}
