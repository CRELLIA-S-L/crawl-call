// The names the scene's entities are given and found by (ART-070). A name is how one
// part of the scene finds another — the match looks the camera up by it — so it is
// declared once and not spelled at each end.
//
// file implements: FR-TOOL-020, FR-VIEW-020, FR-VIEW-100, FR-VIEW-170, FR-MAP-130, FR-GREENHOLM-030, FR-VIEW-260, FR-VIEW-290
import Foundation

enum EntityName {
    static let scene = "scene"
    static let map = "map"
    static let camera = "camera"
    static let ambient = "ambient"
    static let light = "light"
    static let snake = "snake"
    static let head = "head"
    static let body = "body"
    static let eye = "eye"
    static let leftEye = "leftEye"
    static let rightEye = "rightEye"
    static let pupil = "pupil"
    static let leftHip = "leftHip"
    static let rightHip = "rightHip"
    static let bots = "bots"
    static let bot = "bot"
    static let shots = "shots"
    static let shot = "shot"
    /// What a setting draws around the arena (FR-MAP-130, ADR-0031).
    static let scenery = "scenery"
    static let sceneryPart = "sceneryPart"
    static let birds = "birds"
    static let bird = "bird"
    static let leftWing = "leftWing"
    static let rightWing = "rightWing"

    /// A tracer's name ends in the squad that fires it, so that a pool of them can be
    /// sorted by squad again without a table beside it.
    static let redSquadSuffix = "r"
    static let blueSquadSuffix = "b"

    /// `segment<index>`, `bot<id>`: one of many of a kind, by its number.
    static func numbered(_ kind: String, _ number: Int) -> String { kind + String(number) }
    /// The ground slabs of one module, drawn as one mesh (ADR-0047).
    static let slabsPrefix = "slabs:"
    static func slabs(_ module: String) -> String { slabsPrefix + module }
}
