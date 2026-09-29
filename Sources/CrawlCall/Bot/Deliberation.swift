// How a bot decides. Every action it could take is scored, and the highest wins
// (FR-BOT-080); the score of each is the bot's personality applied to what it can
// see (FR-BOT-090).
//
// The inputs are the ones FR-BOT-080 names — distance to cover, health, the snake's
// position, line of fire and ammunition — and the terms below are written so that
// each of them can be varied on its own and the choice watched to move, which is
// what its rationale asks of a test.
//
// The weight of one term against another is tuning, and is read from the bot
// configuration (IF-BOT-010), as is how much an unhurt bot fears the snake
// (FR-BOT-210). What shapes each term — a share, a whole — is in `Utility`.
//
// implements: FR-BOT-080, FR-BOT-090, FR-BOT-118, FR-BOT-200, FR-BOT-210, FR-MAP-150, FR-BOT-220, FR-BOT-060, FR-BOT-140, FR-BOT-330
import Foundation

enum Deliberation {
    /// How far a bot looks for cover, in metres: the distance at which a squad is
    /// still one group (IF-BOT-010), because cover further off than that is somebody
    /// else's.
    static func coverSearch(_ configuration: BotConfiguration) -> Double { configuration.groupingDistance }

    /// What a bot can see and reach when it comes to decide.
    struct Situation {
        /// Where the snake is, as far as this bot knows. Empty when it has not seen
        /// it: an action about the snake is then not available at all, rather than
        /// available and scoring zero.
        var snake: [SIMD3<Double>] = []
        /// The parts of the snake the bot sees now: what it can fire at (FR-BOT-220).
        var inView: [SIMD3<Double>] = []
        /// Whether the bot knows a cell: where it may hide or run to (FR-BOT-220).
        var knows: (NavigationGraph.Node) -> Bool = { _ in true }
        /// Where the enemy bots it knows of were last seen, standing: what it hides
        /// from, as it hides from the snake (FR-BOT-330).
        var enemies: [SIMD3<Double>] = []
        /// The enemy bots it sees now, by id: what it can fire at (FR-BOT-060).
        var enemiesInView: [(id: Int, point: SIMD3<Double>)] = []
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
        // The mix: the weight of one named input in one action's score.
        let term = situation.configuration.utilityTermWeights

        let nearest = situation.snake
            .map { (point: $0, metres: Perception.metres(bot.position, $0)) }
            .min { $0.metres < $1.metres }
        let health = entry.health > .zero ? bot.health / entry.health : .zero
        let ammunition = entry.magazine > .zero ? Double(bot.ammunition) / Double(entry.magazine) : .zero

        // Fire: needs something to shoot at that the bot sees now, a line to it and a
        // round to send; a remembered snake is somewhere to be afraid of, not a target.
        // Of the targets, the nearest part of the snake and each enemy bot in view
        // (FR-BOT-060), the one it is already firing at is kept unless another is
        // worth more by the hysteresis margin (FR-BOT-140).
        if bot.ammunition > .zero,
           let target = target(for: bot, in: situation, worth: { metres in
               term.attack * nearness(metres, within: entry.detectionRange) * ammunition * bot.weights.aggression
           }) {
            scored.append((.fire(at: target.target), target.utility))
        }

        // Cover: worth more the nearer it is, the nearer the danger is — the snake or
        // an enemy (FR-BOT-330) — and the less of the bot is left.
        let danger = (situation.snake + situation.enemies)
            .map { Perception.metres(bot.position, $0) }
            .min()
        if let danger, let cover = cover(for: bot, from: situation.snake, enemies: situation.enemies, in: situation) {
            let reach = coverSearch(situation.configuration)
            let closeness = nearness(danger, within: entry.detectionRange)
            let handy = nearness(Perception.metres(bot.position, centre(of: cover.node, in: situation)), within: reach)
            scored.append((.takeCover(at: cover.node),
                           term.threat * closeness * handy * (term.wounded - health * Utility.coverHealthShare)
                               * bot.weights.panic))
        }

        // Flight: the same fear, spent on distance rather than on a wall. A whole bot
        // is afraid too (FR-BOT-210) — the fear of a wound already taken is what a
        // wound adds, not the whole of what there is to be afraid of.
        if let nearest, let away = away(from: nearest.point, for: bot, in: situation) {
            let closeness = nearness(nearest.metres, within: entry.detectionRange)
            let fear = situation.configuration.fearWhenUnhurt + (term.wounded - health)
            scored.append((.flee(to: away), term.threat * closeness * fear * bot.weights.panic))
        }

        // An order to obey is the one thing discipline scales; without a commander
        // there is no order, and the action is simply not on the list.
        if let zone = situation.orderedZone {
            // Obeying does not get better or worse with distance in anything the
            // specification says; what varies it is how disciplined the bot is.
            scored.append((.moveToOrderedZone(zone), term.obedience * bot.weights.discipline))
        }

        if bot.ammunition < entry.magazine {
            // Squared, so that the term stays flat while there is a magazine to
            // spend and climbs only as it runs out: a bot that reloaded after every
            // shot would spend a firefight looking at its hands.
            let spent = Fraction.whole - ammunition
            scored.append((.reload, term.empty * spent * spent))
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
            // Every ally in `hurt` has an archetype the configuration knows, so the
            // second condition holds whenever the first does.
            if let worst = hurt.min(by: { $0.health < $1.health }),
               let theirs = situation.configuration.archetypes[worst.archetype.rawValue]?.health {
                let missing = theirs > .zero ? Fraction.whole - worst.health / theirs : .zero
                scored.append((.heal(ally: worst.id), term.mercy * missing * bot.weights.selfSacrifice))
            }
        }

        return scored.map { (action: $0.0, utility: $0.1) }
    }

    /// What the bot fires at, and what firing at it is worth: the best of the nearest
    /// part of the snake it sees and each enemy bot it sees with a line of fire to it,
    /// by `worth` of the distance, except that the target it is already firing at is
    /// kept while nothing else is worth more by the hysteresis margin (FR-BOT-140).
    /// Two targets are one where both are the snake, or both the same bot.
    static func target(for bot: Bot, in situation: Situation,
                       worth: (Double) -> Double) -> (target: Target, utility: Double)? {
        var candidates: [(target: Target, utility: Double)] = []
        let snake = situation.inView
            .map { (point: $0, metres: Perception.metres(bot.position, $0)) }
            .min { $0.metres < $1.metres }
        if let snake, Sight.isClear(from: bot.eye, to: snake.point, through: situation.plan) {
            candidates.append((.snake(at: snake.point), worth(snake.metres)))
        }
        for enemy in situation.enemiesInView {
            let eye = enemy.point + SIMD3(0, bot.eyeHeight, 0)
            guard Sight.isClear(from: bot.eye, to: eye, through: situation.plan) else { continue }
            candidates.append((.bot(id: enemy.id), worth(Perception.metres(bot.position, enemy.point))))
        }
        // The first of the best, so that a tie goes the same way every time.
        var best: (target: Target, utility: Double)?
        for candidate in candidates where candidate.utility > (best?.utility ?? -.infinity) { best = candidate }
        guard let best else { return nil }
        guard case .fire(let current) = bot.action,
              let kept = candidates.first(where: { same($0.target, current) }),
              best.utility - kept.utility < situation.configuration.hysteresisMargin else { return best }
        return kept
    }

    /// Whether two targets are one: both the snake, wherever it was aimed at, or both
    /// the same bot.
    static func same(_ a: Target, _ b: Target) -> Bool {
        switch (a, b) {
        case (.snake, .snake): return true
        case (.bot(let x), .bot(let y)): return x == y
        default: return false
        }
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
    ///
    /// A cell is watched by a part of the snake that has a line to its ground, and by
    /// an enemy whose eyes have a line to where the bot's would be, standing in it: an
    /// enemy fires from its eyes at a bot's head, which shows over a wall lower than
    /// both (FR-BOT-330, ADR-0022).
    static func cover(for bot: Bot, from snake: [SIMD3<Double>], enemies: [SIMD3<Double>] = [],
                      in situation: Situation) -> (node: NavigationGraph.Node, metres: Double)? {
        guard !snake.isEmpty || !enemies.isEmpty else { return nil }
        let rise = SIMD3(0, bot.eyeHeight, 0)
        let shooters = enemies.map { $0 + rise }
            .sorted { Perception.metres(bot.position, $0) < Perception.metres(bot.position, $1) }
        let reach = coverSearch(situation.configuration)
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }
        // The parts nearest the bot are asked first: the cells searched lie around the
        // bot, and a part near a cell is the likeliest to see into it, so a watched cell
        // is known after one or two sight tests rather than after the whole tail. Which
        // part sees it does not change whether one does (ADR-0028).
        let byNearness = snake.sorted { Perception.metres(bot.position, $0) < Perception.metres(bot.position, $1) }

        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            let there = centre(of: node, in: situation)
            let metres = Perception.metres(bot.position, there)
            guard metres <= reach else { continue }
            // Only a cell the bot knows is somewhere it would think of hiding (FR-BOT-220).
            if metres > .zero, situation.knows(node) {
                let watched = byNearness.contains { Sight.isClear(from: $0, to: there, through: situation.plan) }
                    || shooters.contains { Sight.isClear(from: $0, to: there + rise, through: situation.plan) }
                if !watched { return (node: node, metres: metres) }
            }
            for next in situation.graph.neighbours(of: node).sorted(by: order)
            where next.floor == bot.floor && seen.insert(next).inserted {
                queue.append(next)
            }
        }
        return nil
    }

    /// The cell within the search distance that puts the most ground between the bot
    /// and what it is running from, out of those it can actually get to.
    ///
    /// Walked outwards over the graph, as cover is (FR-BOT-118): a spot picked by how
    /// far away it lies can be on the other side of a wall, and a bot that sets off
    /// for one and then stops is the standing still concept §9.2 calls the signature
    /// stupidity. Walking the graph makes the answer reachable by construction rather
    /// than by a second test afterwards.
    static func away(from danger: SIMD3<Double>, for bot: Bot,
                     in situation: Situation) -> NavigationGraph.Node? {
        let reach = coverSearch(situation.configuration)
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }

        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        var best: (NavigationGraph.Node, Double)?
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            let there = centre(of: node, in: situation)
            // Out of reach is also as far as the walk goes: what lies beyond is only
            // approached through cells the bot would have to cross to get there.
            guard Perception.metres(bot.position, there) <= reach else { continue }
            let gained = Perception.metres(there, danger)
            // Only a cell the bot knows is somewhere it would think of running to
            // (FR-BOT-220).
            if situation.knows(node), best == nil || gained > best!.1 { best = (node, gained) }
            for next in situation.graph.neighbours(of: node).sorted(by: order)
            where next.floor == bot.floor && seen.insert(next).inserted {
                queue.append(next)
            }
        }
        guard let best, best.1 > Perception.metres(bot.position, danger) else { return nil }
        return best.0
    }

    /// One order over cells, so that a walk outwards is the same walk every time.
    private static func order(_ a: NavigationGraph.Node, _ b: NavigationGraph.Node) -> Bool {
        (a.floor, a.z, a.x) < (b.floor, b.z, b.x)
    }

    static func centre(of node: NavigationGraph.Node, in situation: Situation) -> SIMD3<Double> {
        situation.graph.centre(of: node, cellSize: situation.cellSize, floorHeight: situation.plan.floorHeight)
    }

    /// One at arm's length, nothing at the edge of the world.
    private static func nearness(_ metres: Double, within limit: Double) -> Double {
        guard limit > .zero else { return .zero }
        return max(.zero, Fraction.whole - metres / limit)
    }
}
