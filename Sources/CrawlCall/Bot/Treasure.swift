// The treasure of the second act: where it is, who is carrying it, and the cell it has
// to reach (FR-MAP-290, FR-BOT-630, FR-BOT-650, FR-SCORE-160).
//
// One value with three states and no fourth: it lies somewhere, a bot carries it, or it
// has been carried off and the match is over. A bot that falls with it puts it back into
// the first state where it stood (FR-BOT-650), which is why `lying` holds a point and
// not the cell the map named — after the first carrier the two are rarely the same.
//
// It sits with the squads rather than with the match because the deliberation is what
// reads it: going for it and carrying it are two actions scored like any other
// (FR-BOT-620, FR-BOT-640), and what the match does with it each frame is the one rule
// below, which takes the bots and knows nothing else about the match.
//
// file implements: FR-MAP-290, FR-BOT-630, FR-BOT-650, FR-SCORE-160, FR-BOT-700, FR-BOT-720
import Foundation

struct Treasure: Equatable {
    /// Where the treasure is.
    enum Place: Equatable {
        /// On the ground at a point of a floor: where the map put it, or where its last
        /// carrier fell (FR-BOT-650).
        case lying(at: SIMD3<Double>, floor: Int)
        /// In the hands of the bot with this id (FR-BOT-630).
        case carried(by: Int)
        /// Carried to the evacuation point; the match ended with it (FR-SCORE-160).
        case carriedOff
    }

    var place: Place
    /// The cell the map names as the evacuation point (FR-BOT-640, FR-SCORE-160).
    let evacuation: NavigationGraph.Node

    /// The bot carrying it, if one is.
    var carrier: Int? {
        if case .carried(let id) = place { return id }
        return nil
    }

    /// Where it lies, if it is lying anywhere: what a bot goes to in order to take it
    /// (FR-BOT-620) and what the view draws on the ground (FR-VIEW-370).
    var lying: (point: SIMD3<Double>, floor: Int)? {
        if case .lying(let point, let floor) = place { return (point, floor) }
        return nil
    }

    /// One frame of the second act, and the whole of what the match does with the
    /// treasure: a carrier that has fallen drops it where it stood (FR-BOT-650), a bot
    /// standing where it lies that may take it picks it up (FR-BOT-630), and a carrier
    /// standing on the evacuation point has carried it off (FR-SCORE-160), which is
    /// what the returned flag says.
    ///
    /// Picking it up is not a decision: a bot that may take it and stands on it has
    /// taken it, whatever it came there to do — which is why this is the match's rule
    /// and not an action of the deliberation's.
    ///
    /// `held` is where the carrier stood as the frame began, kept across frames by the
    /// caller, because a bot the snake finishes eating is gone from `bots` before the
    /// frame ends and the treasure still has to fall where that bot was.
    mutating func step(among bots: [Bot],
                       cell: (Bot) -> NavigationGraph.Node,
                       cellOf: (SIMD3<Double>) -> NavigationGraph.Node?,
                       mayHold: (Bot) -> Bool = { _ in true },
                       held: inout (point: SIMD3<Double>, floor: Int)?) -> Bool {
        if let carrier {
            guard let holder = bots.first(where: { $0.id == carrier }), holder.isAlive else {
                // Shot or eaten: left where that bot was, for the next bot that may to
                // pick up (FR-BOT-650).
                let fell = bots.first { $0.id == carrier }.map { (point: $0.position, floor: $0.floor) } ?? held
                if let fell { place = .lying(at: fell.point, floor: fell.floor) }
                held = nil
                return false
            }
            // Its crew has found somebody to fight and this bot's greed does not
            // outweigh its fear, so the prize goes down where it stands and the hands
            // that carried it are free again (FR-BOT-700). Putting it down is no more a
            // decision than picking it up: the match does it, and the bot is a soldier
            // again in the same frame. A greedier one keeps the box and walks on with
            // the fighting behind it (ADR-0100).
            guard mayHold(holder) else {
                place = .lying(at: holder.position, floor: holder.floor)
                held = nil
                return false
            }
            held = (holder.position, holder.floor)
            guard cell(holder) == evacuation else { return false }
            // Standing on the point is not leaving with it (FR-SCORE-160): while one
            // of the other crew is still up, there is nobody to walk past, and the
            // carrier waits there with the prize in its arms until its squad has
            // cleared the way or somebody takes the prize off its body.
            guard !bots.contains(where: { $0.squad != holder.squad && $0.isAlive }) else { return false }
            place = .carriedOff
            held = nil
            return true
        }
        guard let lying, let node = cellOf(lying.point) else { return false }
        // The lowest id of those standing in its cell that may take it, so that a match
        // is the same twice over. In a fight that is the bot whose greed outweighs its
        // own fear and nobody else (FR-BOT-720): the one that would put it down again
        // in the next frame never picks it up.
        let taker = bots
            .filter { $0.isAlive && mayHold($0) && cell($0) == node }
            .min { $0.id < $1.id }
        guard let taker else { return false }
        place = .carried(by: taker.id)
        held = (taker.position, taker.floor)
        return false
    }
}
