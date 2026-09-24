// The names the scene's entities are given and found by (ART-070). A name is how one
// part of the scene finds another — the match looks the camera up by it — so it is
// declared once and not spelled at each end.
//
// implements: FR-TOOL-020
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

    /// `segment<index>`, `bot<id>`: one of many of a kind, by its number.
    static func numbered(_ kind: String, _ number: Int) -> String { kind + String(number) }
}
