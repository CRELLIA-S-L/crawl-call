// What a bot may choose to do. The set is the floor the specification names, not a
// catalogue: an archetype may add to it, and nothing may quietly drop out of it
// (FR-BOT-200).
//
// implements: FR-BOT-200
import Foundation

/// What a shot is aimed at. The snake is named by the point that is being shot at —
/// a tail segment is a target in its own right, which is what makes shooting at the
/// tail a meaningful thing to do (FR-SNAKE-070).
enum Target: Equatable {
    case snake(at: SIMD3<Double>)
    case bot(id: Int)
}

enum Action: Equatable {
    case fire(at: Target)
    case takeCover(at: NavigationGraph.Node)
    case moveToOrderedZone(NavigationGraph.Node)
    case flee(to: NavigationGraph.Node)
    case reload
    case heal(ally: Int)
}
