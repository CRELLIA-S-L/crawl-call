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
// implements: FR-BOT-080, FR-BOT-090, FR-BOT-110, FR-BOT-115, FR-BOT-118, FR-BOT-360, FR-BOT-370, FR-BOT-120, FR-BOT-180, FR-BOT-190, FR-BOT-200, FR-BOT-210, FR-MAP-150, FR-BOT-220, FR-BOT-060, FR-BOT-140, FR-BOT-330
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
        /// Where the bot takes the snake's head to be: the part nearest the head it
        /// has seen, where it saw it (FR-BOT-220). Nil where it has seen none, and a
        /// position is then worth what it was without the snake (FR-BOT-110, FR-BOT-115).
        var snakeHead: SIMD3<Double>?
        /// Steps over the graph from the cell of `snakeHead` to every cell the snake
        /// can reach from it (FR-BOT-115).
        var fromHead: [NavigationGraph.Node: Int] = [:]
        /// Where the bot believes the enemy squad to be, if anywhere it has not already
        /// been: the latest place it saw or was told of an enemy bot, or else the
        /// enemy's starting area (FR-BOT-360).
        var enemyBelief: SIMD3<Double>?
        /// What the bot's squad knows of the snake (FR-SCORE-130). A situation built
        /// without it takes the snake as known, which is how every bot behaved before
        /// squads had a state.
        var awareness: Awareness = .confirmed
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
            // Within the override distance the snake is the top threat, whatever else
            // there is and whatever the bot was firing at (FR-BOT-120); beyond it, a calm
            // squad does not hunt it (FR-BOT-180).
            if snake.metres <= situation.configuration.overrideDistance {
                return (.snake(at: snake.point), worth(snake.metres))
            }
            if situation.awareness != .calm { candidates.append((.snake(at: snake.point), worth(snake.metres))) }
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
    ///
    /// Where every action on the list scores nothing — or there is none — the bot has
    /// nothing to do, and goes on towards the enemy or to see what it has not seen
    /// (FR-BOT-360, FR-BOT-370): a motive for the quiet is never weighed against
    /// anything that scores, so it can never outweigh a threat (ADR-0059).
    static func choose(for bot: Bot, in situation: Situation) -> Action? {
        var best: (action: Action, utility: Double)?
        for candidate in scores(for: bot, in: situation) where candidate.utility > (best?.utility ?? -.infinity) {
            best = candidate
        }
        guard let best, best.utility > .zero else { return quiet(for: bot, in: situation) ?? best?.action }
        return best.action
    }

    /// What a bot with nothing else to do goes and does: on towards the enemy, or to
    /// the nearest cell it has not seen, the one its aggression weighs more — the
    /// advance by its aggression, the look by what is left of it; the advance where the
    /// two are equal. Nil where it has neither anywhere to advance to nor anything
    /// unseen it can reach.
    static func quiet(for bot: Bot, in situation: Situation) -> Action? {
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }
        let advance = situation.enemyBelief.flatMap { nearestCell(to: $0, from: here, in: situation) }
        let explore = unseen(from: here, in: situation)
        let aggression = bot.weights.aggression
        switch (advance, explore) {
        case (let target?, let look?):
            return aggression >= Fraction.whole - aggression ? .advance(to: target) : .explore(to: look)
        case (let target?, nil): return .advance(to: target)
        case (nil, let look?): return .explore(to: look)
        case (nil, nil): return nil
        }
    }

    /// The nearest cell, along the walk from where the bot stands and other than the
    /// one it stands in, that it does not know (FR-BOT-370), on any floor the graph
    /// joins.
    static func unseen(from here: NavigationGraph.Node, in situation: Situation) -> NavigationGraph.Node? {
        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            if node != here, !situation.knows(node) { return node }
            for next in situation.graph.neighbours(of: node).sorted(by: order) where seen.insert(next).inserted {
                queue.append(next)
            }
        }
        return nil
    }

    /// The walkable cell that lies nearest a point across the room, and is not the one
    /// the bot stands in: where it goes to be at the point. Every cell of the graph is
    /// weighed rather than walked to, which took a tenth of the time on the simulator
    /// (Q-460); a cell the bot cannot get to is spent at routing, as any is
    /// (FR-BOT-167).
    static func nearestCell(to point: SIMD3<Double>, from here: NavigationGraph.Node,
                            in situation: Situation) -> NavigationGraph.Node? {
        var best: (node: NavigationGraph.Node, metres: Double)?
        for node in situation.graph.nodes where node != here {
            let metres = Perception.metres(centre(of: node, in: situation), point)
            if best == nil || metres < best!.metres || (metres == best!.metres && order(node, best!.node)) {
                best = (node, metres)
            }
        }
        return best?.node
    }

    /// What a position is worth: one, raised by its height above the snake's head up to
    /// a floor (FR-BOT-110), by the length of the snake's shortest path to it up to the
    /// bot's detection range (FR-BOT-115) — a cell the snake cannot reach at all being as
    /// far as a path can count — and, while the bot's squad is alarmed, by lying within
    /// the grouping distance of a squadmate (FR-BOT-190). One where the bot knows no
    /// snake and its squad is not alarmed.
    ///
    /// It decides where a bot hides or runs to, not how much it wants to: multiplied into
    /// the wish itself, it made hiding and running up to three times what firing is
    /// worth, and the squads all but stopped shooting (ADR-0058).
    static func worth(of node: NavigationGraph.Node, for bot: Bot, in situation: Situation) -> Double {
        let term = situation.configuration.utilityTermWeights
        // An alarmed squad keeps together (FR-BOT-190): a position within the grouping
        // distance of a squadmate is worth more.
        let together = situation.awareness == .alarm && situation.allies.contains { ally in
            ally.id != bot.id && ally.squad == bot.squad && ally.isAlive
                && Perception.metres(ally.position, centre(of: node, in: situation))
                    <= situation.configuration.groupingDistance
        } ? term.together : .zero
        guard let head = situation.snakeHead,
              let range = situation.configuration.archetypes[bot.archetype.rawValue]?.detectionRange,
              range > .zero else { return Fraction.whole + together }
        let floor = situation.plan.floorHeight
        let above = floor > .zero ? (centre(of: node, in: situation).y - head.y) / floor : .zero
        let path = situation.fromHead[node].map {
            Double($0) / Double(MapGrid.stepsPerNeighbour) * situation.cellSize / range
        } ?? Fraction.whole
        return Fraction.whole + term.height * clamped(above) + term.snakePath * clamped(path) + together
    }

    /// Between nothing and one.
    private static func clamped(_ share: Double) -> Double { min(Fraction.whole, max(.zero, share)) }

    /// The cell a point stands in, for the snake's head on the graph (FR-BOT-115): the
    /// floor its height is on, or, where that cell is not walkable, the nearest floor
    /// below on which it is. Nil where there is none.
    static func cell(of point: SIMD3<Double>, graph: NavigationGraph, cellSize: Double,
                     floorHeight: Double) -> NavigationGraph.Node? {
        let x = Int((point.x / cellSize).rounded()), z = Int((point.z / cellSize).rounded())
        let top = floorHeight > .zero ? Int((point.y / floorHeight + Placing.floorSlack).rounded(.down)) : .zero
        for floor in stride(from: top, through: .zero, by: -1) {
            let node = NavigationGraph.Node(floor: floor, x: x, z: z)
            if graph.isWalkable(node) { return node }
        }
        return nil
    }

    /// The best-placed reachable cell the snake cannot see into, if there is one
    /// within the search distance: the nearest, raised by what the position is worth
    /// (FR-BOT-110, FR-BOT-115, FR-BOT-190).
    ///
    /// The cells are those the bot can walk to within reach, on any floor (`walk`),
    /// ranked before sight is asked about, and asked about best first (ADR-0058).
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

        // Every cell it knows within reach, ranked by what hiding there would be worth
        // before anything is asked about sight — nearness raised by the position's
        // worth — and asked about in that order: the first that nothing watches is the
        // best, and every sight test after it would be asked about a worse answer
        // (NFR-PERF-020).
        let ranked = walk(from: here, within: reach, for: bot, in: situation)
            .filter { $0.metres > .zero && situation.knows($0.node) }
            .map { cell in
                (cell: cell, rank: nearness(cell.metres, within: reach) * worth(of: cell.node, for: bot, in: situation))
            }
            .enumerated()
            .sorted { $0.element.rank != $1.element.rank ? $0.element.rank > $1.element.rank : $0.offset < $1.offset }
            .map(\.element.cell)
        for cell in ranked {
            let there = centre(of: cell.node, in: situation)
            let watched = byNearness.contains { Sight.isClear(from: $0, to: there, through: situation.plan) }
                || shooters.contains { Sight.isClear(from: $0, to: there + rise, through: situation.plan) }
            if !watched { return (node: cell.node, metres: cell.metres) }
        }
        return nil
    }

    /// The cells a bot can walk to without leaving the search distance, on any floor
    /// the graph joins (FR-BOT-110), nearest along the walk first, each with how far
    /// it is from the bot across the room.
    ///
    /// Walked outwards over the graph rather than scanned over the map, so that every
    /// cell given is one the bot can get to (FR-BOT-118); out of reach is also as far
    /// as the walk goes, since what lies beyond is only approached through cells the
    /// bot would have to cross to get there.
    static func walk(from here: NavigationGraph.Node, within reach: Double, for bot: Bot,
                     in situation: Situation) -> [(node: NavigationGraph.Node, metres: Double)] {
        var cells: [(node: NavigationGraph.Node, metres: Double)] = []
        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            let metres = Perception.metres(bot.position, centre(of: node, in: situation))
            guard metres <= reach else { continue }
            cells.append((node: node, metres: metres))
            for next in situation.graph.neighbours(of: node).sorted(by: order) where seen.insert(next).inserted {
                queue.append(next)
            }
        }
        return cells
    }

    /// The cell within the search distance that puts the most ground between the bot
    /// and what it is running from, raised by what the position is worth against the
    /// snake (FR-BOT-110, FR-BOT-115), out of those it can actually get to.
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

        // Ground gained, raised by what the position is worth against the snake
        // (FR-BOT-110, FR-BOT-115). Only a cell the bot knows is somewhere it would think
        // of running to (FR-BOT-220).
        var best: (node: NavigationGraph.Node, gained: Double, value: Double)?
        for cell in walk(from: here, within: reach, for: bot, in: situation) where situation.knows(cell.node) {
            let gained = Perception.metres(centre(of: cell.node, in: situation), danger)
            let value = gained * worth(of: cell.node, for: bot, in: situation)
            if best == nil || value > best!.value { best = (cell.node, gained, value) }
        }
        guard let best, best.gained > Perception.metres(bot.position, danger) else { return nil }
        return best.node
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
