// What the input layer hands the game logic, and the only thing the logic reads.
// "Exactly these" is the contract: a scheme that needs a fifth intent changes
// IF-VIEW-010 first, and this type after it.
//
// implements: IF-VIEW-010
import Foundation

enum Intent: Equatable {
    /// Where the player is steering, as a direction on the map plane.
    case move(direction: SIMD2<Double>)
    /// Use the ability hanging on one segment of the tail, named by its index.
    case useAbility(segment: Int)
    /// A position the player pointed at, in map coordinates.
    case point(at: SIMD2<Double>)
    /// Pause.
    case pause

    /// The four the contract names. A scheme is complete when it can produce each of
    /// them, and the logic is honest when it consumes nothing else.
    static let all: [String] = ["move", "useAbility", "point", "pause"]
}
