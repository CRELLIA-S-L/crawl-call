// Where an order sends a bot. The commander names one of five orders for the whole
// squad (FR-CMD-040); each bot turns that into one cell to be in, which is the single
// hook the deliberation has for an order — `Situation.orderedZone`, scored by the
// obedience term since FR-BOT-090 and nil in play until now.
//
// Four of the five orders have a cell to name and the fifth does not: destroying the
// enemy's cover needs a bot that can wreck a wall, which is FR-BOT-070 and is not
// built. An order with no cell leaves the deliberation exactly as it was — no order
// action on the list, and the local terms undamped (FR-BOT-130) — which is the honest
// reading of an order the game cannot carry out yet.
//
// Every cell named here is one the bot knows (FR-BOT-220) and can walk to within the
// distance a squad stays together over (IF-BOT-010), so a destination is reachable by
// construction rather than by a check afterwards — the same rule cover and flight are
// found by (FR-BOT-118, ADR-0058).
//
// file implements: FR-CMD-040
import Foundation

enum Orders {
    /// The cell this bot is to be in under its squad's order, or nil where the order
    /// names none it can reach.
    static func zone(for bot: Bot, under order: CommanderDecision.Order,
                     in situation: Deliberation.Situation) -> NavigationGraph.Node? {
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }
        switch order {
        case .hold:
            // Where it stands. The order then costs no walking and is worth the
            // obedience term all the same, which is what holding ground is: the thing
            // discipline has to beat fear with (FR-BOT-130).
            return here
        case .flank:
            return flank(for: bot, from: here, in: situation)
        case .withdrawToZone:
            return retreat(for: bot, in: situation)
        case .disperse:
            return apart(for: bot, from: here, in: situation)
        case .destroyCover:
            return nil
        }
    }

    /// Round the side: of the cells the bot can reach, the one that stands furthest off
    /// the straight line to where it believes the enemy to be, without giving ground —
    /// a cell no further from the enemy than the bot already is.
    ///
    /// Nil where it believes nothing about the enemy: flanking a crew nobody has seen
    /// is a direction, not a cell.
    private static func flank(for bot: Bot, from here: NavigationGraph.Node,
                              in situation: Deliberation.Situation) -> NavigationGraph.Node? {
        guard let enemy = situation.enemyBelief else { return nil }
        let axis = enemy - bot.position
        let length = (axis.x * axis.x + axis.z * axis.z).squareRoot()
        guard length > .zero else { return nil }
        let forward = SIMD3<Double>(axis.x / length, .zero, axis.z / length)
        let standing = Perception.metres(bot.position, enemy)
        var best: (node: NavigationGraph.Node, sideways: Double)?
        for cell in Deliberation.walk(from: here, within: reach(situation), for: bot, in: situation)
        where situation.knows(cell.node) {
            let centre = Deliberation.centre(of: cell.node, in: situation)
            guard Perception.metres(centre, enemy) <= standing else { continue }
            let step = centre - bot.position
            let along = step.x * forward.x + step.z * forward.z
            let side = SIMD3<Double>(step.x - along * forward.x, .zero, step.z - along * forward.z)
            let sideways = (side.x * side.x + side.z * side.z).squareRoot()
            if sideways > (best?.sideways ?? .zero) { best = (cell.node, sideways) }
        }
        return best?.node
    }

    /// Out of it: the cell that puts the most ground between the bot and the nearest
    /// thing it is afraid of, which is the one flight already finds (FR-BOT-220).
    /// Nil where it knows of nothing to withdraw from.
    private static func retreat(for bot: Bot, in situation: Deliberation.Situation) -> NavigationGraph.Node? {
        let danger = (situation.snake + situation.enemies)
            .min { Perception.metres(bot.position, $0) < Perception.metres(bot.position, $1) }
        guard let danger else { return nil }
        return Deliberation.away(from: danger, for: bot, in: situation)
    }

    /// Spread out: of the cells the bot can reach, the one furthest from its nearest
    /// squadmate, and only where that is further than where it stands. Nil where it
    /// stands alone — a squad of one is already dispersed.
    private static func apart(for bot: Bot, from here: NavigationGraph.Node,
                              in situation: Deliberation.Situation) -> NavigationGraph.Node? {
        let mates = situation.allies.filter { $0.id != bot.id && $0.squad == bot.squad && $0.isAlive }
        guard !mates.isEmpty else { return nil }
        func nearestMate(_ point: SIMD3<Double>) -> Double {
            mates.map { Perception.metres(point, $0.position) }.min() ?? .zero
        }
        let standing = nearestMate(bot.position)
        var best: (node: NavigationGraph.Node, gap: Double)?
        for cell in Deliberation.walk(from: here, within: reach(situation), for: bot, in: situation)
        where situation.knows(cell.node) {
            let gap = nearestMate(Deliberation.centre(of: cell.node, in: situation))
            if gap > (best?.gap ?? standing) { best = (cell.node, gap) }
        }
        return best?.node
    }

    /// How far a bot goes to carry out an order: the distance over which a squad is
    /// still one group (IF-BOT-010), the same reach cover and flight are looked for
    /// within. An order is not a march across the arena; it is where to stand next.
    private static func reach(_ situation: Deliberation.Situation) -> Double {
        Deliberation.coverSearch(situation.configuration)
    }
}
