// How a bot decides. Every action it could take is scored, and the highest wins
// (FR-BOT-080); the score of each is the bot's personality applied to what it can
// see (FR-BOT-090).
//
// The inputs are the ones FR-BOT-080 names — distance to cover, health, the snake's
// position, line of fire and ammunition — and the terms below are written so that
// each of them can be varied on its own and the choice watched to move, which is
// what its rationale asks of a test.
//
// The weight of one term against another is tuning, and tuning has a home for the
// numbers an interface names (IF-BOT-010) and none for these. They sit here as
// named constants rather than as magic numbers in expressions, said out loud: when
// the maintainer wants to tune the mix, this table moves into the bot configuration
// and the interface requirement gains a line.
//
// implements: FR-BOT-080, FR-BOT-090, FR-BOT-200
import Foundation

enum Deliberation {
    /// How far a bot looks for cover, in metres: the distance at which a squad is
    /// still one group (IF-BOT-010), because cover further off than that is somebody
    /// else's.
    static func coverSearch(_ configuration: BotConfiguration) -> Double { configuration.groupingDistance }

    /// The mix. Each is the weight of one named input in one action's score.
    enum Term {
        static let attack = 1.0
        static let threat = 1.0
        static let wounded = 1.0
        static let obedience = 1.0
        static let mercy = 1.0
        static let empty = 1.2
    }

    /// What a bot can see and reach when it comes to decide.
    struct Situation {
        /// Where the snake is, as far as this bot knows. Empty when it has not seen
        /// it: an action about the snake is then not available at all, rather than
        /// available and scoring zero.
        var snake: [SIMD3<Double>] = []
        var allies: [Bot] = []
        var orderedZone: NavigationGraph.Node?
        let plan: ScenePlan
        let graph: NavigationGraph
        let configuration: BotConfiguration
        let cellSize: Double
    }

    /// Every action available to this bot, with what it is worth to it.
    static func scores(for bot: Bot, in situation: Situation) -> [(action: Action, utility: Double)] {
        var scored: [(Action, Double)] = []
        guard let entry = situation.configuration.archetypes[bot.archetype.rawValue] else { return [] }

        let nearest = situation.snake
            .map { (point: $0, metres: Perception.metres(bot.position, $0)) }
            .min { $0.metres < $1.metres }
        let health = entry.health > 0 ? bot.health / entry.health : 0
        let ammunition = entry.magazine > 0 ? Double(bot.ammunition) / Double(entry.magazine) : 0

        // Fire: needs something to shoot at, a line to it and a round to send.
        if let nearest, bot.ammunition > 0,
           Sight.isClear(from: bot.position, to: nearest.point, through: situation.plan) {
            let closeness = nearness(nearest.metres, within: entry.detectionRange)
            scored.append((.fire(at: .snake(at: nearest.point)),
                           Term.attack * closeness * ammunition * bot.weights.aggression))
        }

        // Cover: worth more the nearer it is, the nearer the snake is and the less
        // of the bot is left.
        if let nearest, let cover = cover(for: bot, from: situation.snake, in: situation) {
            let reach = coverSearch(situation.configuration)
            let closeness = nearness(nearest.metres, within: entry.detectionRange)
            let handy = nearness(Perception.metres(bot.position, centre(of: cover.node, in: situation)), within: reach)
            scored.append((.takeCover(at: cover.node),
                           Term.threat * closeness * handy * (Term.wounded - health / 2) * bot.weights.panic))
        }

        // Flight: the same fear, spent on distance rather than on a wall.
        if let nearest, let away = away(from: nearest.point, for: bot, in: situation) {
            let closeness = nearness(nearest.metres, within: entry.detectionRange)
            scored.append((.flee(to: away),
                           Term.threat * closeness * (Term.wounded - health) * bot.weights.panic))
        }

        // An order to obey is the one thing discipline scales; without a commander
        // there is no order, and the action is simply not on the list.
        if let zone = situation.orderedZone {
            // Obeying does not get better or worse with distance in anything the
            // specification says; what varies it is how disciplined the bot is.
            scored.append((.moveToOrderedZone(zone), Term.obedience * bot.weights.discipline))
        }

        if bot.ammunition < entry.magazine {
            // Squared, so that the term stays flat while there is a magazine to
            // spend and climbs only as it runs out: a bot that reloaded after every
            // shot would spend a firefight looking at its hands.
            let spent = 1 - ammunition
            scored.append((.reload, Term.empty * spent * spent))
        }

        // Only a medic heals, and only somebody who needs it and is within the
        // distance at which a squad is still together.
        if bot.archetype == .medic {
            let hurt = situation.allies
                .filter { $0.id != bot.id && $0.squad == bot.squad }
                .filter { ally in
                    guard let theirs = situation.configuration.archetypes[ally.archetype.rawValue] else { return false }
                    return ally.health < theirs.health
                        && Perception.metres(bot.position, ally.position) <= situation.configuration.groupingDistance
                }
            if let worst = hurt.min(by: { $0.health < $1.health }) {
                let theirs = situation.configuration.archetypes[worst.archetype.rawValue]?.health ?? 1
                let missing = theirs > 0 ? 1 - worst.health / theirs : 0
                scored.append((.heal(ally: worst.id), Term.mercy * missing * bot.weights.selfSacrifice))
            }
        }

        return scored.map { (action: $0.0, utility: $0.1) }
    }

    /// The action with the highest score, or nothing when a bot has nothing to do.
    /// Ties go to the action scored first, which keeps a match repeatable.
    static func choose(for bot: Bot, in situation: Situation) -> Action? {
        var best: (action: Action, utility: Double)?
        for candidate in scores(for: bot, in: situation) where candidate.utility > (best?.utility ?? -.infinity) {
            best = candidate
        }
        return best?.action
    }

    /// The nearest reachable cell the snake cannot see into, if there is one within
    /// the search distance.
    ///
    /// Walked outwards from the bot rather than scanned over the map, and stopped at
    /// the first cell that is hidden: cells come out in order of how far they are, so
    /// the first hidden one is the nearest, and every sight test after it would be
    /// asked about a worse answer. On the blockout that is a handful of tests where
    /// the scan was three hundred (NFR-PERF-020).
    static func cover(for bot: Bot, from snake: [SIMD3<Double>],
                      in situation: Situation) -> (node: NavigationGraph.Node, metres: Double)? {
        guard !snake.isEmpty else { return nil }
        let reach = coverSearch(situation.configuration)
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }

        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            let there = centre(of: node, in: situation)
            let metres = Perception.metres(bot.position, there)
            guard metres <= reach else { continue }
            if metres > 0 {
                let watched = snake.contains { Sight.isClear(from: $0, to: there, through: situation.plan) }
                if !watched { return (node: node, metres: metres) }
            }
            for next in situation.graph.neighbours(of: node).sorted(by: order)
            where next.floor == bot.floor && seen.insert(next).inserted {
                queue.append(next)
            }
        }
        return nil
    }

    /// The reachable cell within the search distance that puts the most ground
    /// between the bot and what it is running from.
    static func away(from danger: SIMD3<Double>, for bot: Bot,
                     in situation: Situation) -> NavigationGraph.Node? {
        let reach = coverSearch(situation.configuration)
        var best: (NavigationGraph.Node, Double)?
        for node in situation.graph.nodes where node.floor == bot.floor {
            let there = centre(of: node, in: situation)
            guard Perception.metres(bot.position, there) <= reach else { continue }
            let gained = Perception.metres(there, danger)
            if best == nil || gained > best!.1 { best = (node, gained) }
        }
        guard let best, best.1 > Perception.metres(bot.position, danger) else { return nil }
        return best.0
    }

    /// One order over cells, so that a walk outwards is the same walk every time.
    private static func order(_ a: NavigationGraph.Node, _ b: NavigationGraph.Node) -> Bool {
        (a.floor, a.z, a.x) < (b.floor, b.z, b.x)
    }

    static func centre(of node: NavigationGraph.Node, in situation: Situation) -> SIMD3<Double> {
        SIMD3(Double(node.x) * situation.cellSize,
              Double(node.floor) * situation.plan.floorHeight,
              Double(node.z) * situation.cellSize)
    }

    /// One at arm's length, nothing at the edge of the world.
    private static func nearness(_ metres: Double, within limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return max(0, 1 - metres / limit)
    }
}
