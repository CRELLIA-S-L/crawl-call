// What a bot may choose to do. The set is the floor the specification names, not a
// catalogue: an archetype may add to it, and nothing may quietly drop out of it
// (FR-BOT-200).
//
// file implements: FR-BOT-200, FR-BOT-540, FR-BOT-570, FR-BOT-460, FR-BOT-470, FR-BOT-510, FR-BOT-520, FR-BOT-360, FR-BOT-370, FR-BOT-620, FR-BOT-640
import Foundation

/// What a shot is aimed at. The snake is named by the point that is being shot at —
/// a tail segment is a target in its own right, which is what makes shooting at the
/// tail a meaningful thing to do (FR-SNAKE-070).
enum Target: Equatable {
    case snake(at: SIMD3<Double>)
    case bot(id: Int)
}

enum Action: Equatable {
    /// Firing at a target with one named weapon: each firearm a bot carries that has a
    /// round left and reaches is an action of its own, so that which one it uses is
    /// decided by the score and not by a rule (FR-BOT-460).
    case fire(at: Target, with: Arms.Slot)
    /// Throwing a grenade where the target is: another weapon that reaches, scored
    /// as an action of its own (FR-BOT-460, FR-BOT-470).
    case throwGrenade(at: Target)
    /// The knife, at the reach of an arm (FR-BOT-510), and thrown a little further at
    /// the cost of having it at all (FR-BOT-520).
    case strike(at: Target)
    case throwKnife(at: Target)
    /// Going to a cell from which a weapon that does not reach its target would reach
    /// it (FR-BOT-570): the rush, scored like the firing it is for.
    case close(on: Target, to: NavigationGraph.Node)
    case takeCover(at: NavigationGraph.Node)
    case moveToOrderedZone(NavigationGraph.Node)
    case flee(to: NavigationGraph.Node)
    /// Filling one firearm's magazine: each that is not full and has a spare left is
    /// an action of its own (FR-BOT-540), as firing each is (FR-BOT-460).
    case reload(Arms.Slot)
    case heal(ally: Int)
    /// With nothing else worth doing: towards where the bot believes the enemy squad
    /// is (FR-BOT-360), or to a cell it has not seen (FR-BOT-370).
    case advance(to: NavigationGraph.Node)
    case explore(to: NavigationGraph.Node)
    /// The second act, which is two motives and not a mode (concept §9.2): going to
    /// where the treasure lies, open only to a bot that believes the enemy gone
    /// (FR-BOT-620), and carrying it to the evacuation point (FR-BOT-640).
    case takeTreasure(at: NavigationGraph.Node)
    case carryTreasure(to: NavigationGraph.Node)
}
