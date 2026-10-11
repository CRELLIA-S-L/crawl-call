// What a match is handed to run on, assembled once before it starts: the tuning, the
// kit, the map as parsed, the setting it names, the graph the bots path over and the
// geometry the player sees.
//
// It sits with the map layer, which produces four of its six parts, and below everything
// that reads it — the match, the squads and the scenery all take it — rather than with
// the start-up that fills it in. Declared beside the pipeline that makes it, a value every
// part of play reads cannot be reached upward for (ADR-0073).
//
// file implements: FR-MAP-020, FR-MAP-160
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
