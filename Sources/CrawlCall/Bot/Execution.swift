// What the bots actually do. Two clocks meet here: deliberation, which runs on its
// own fixed step (FR-BOT-150), and execution, which runs every frame for every
// living bot (INV-BOT-010) — a decision arriving late goes unnoticed, a body moving
// at seven frames a second does not.
//
// A shot is fired by the deliberation step rather than by the frame, so that a bot
// firing at sixty frames a second and one firing at thirty deal the same damage a
// second. Cadence is therefore the deliberation period, and that is a statement
// rather than an accident: no requirement gives a weapon a rate of fire, and
// inventing one would put a number in this file that no interface carries.
//
// implements: FR-BOT-060, FR-VIEW-170, INV-BOT-010, FR-BOT-165
import Foundation

enum Execution {
    /// What one deliberation step did: the damage the snake takes, and the shots that
    /// dealt it, to be drawn where they went (FR-VIEW-170).
    struct Volley: Equatable {
        var damage: Double = .zero
        var shots: [Shot] = []
    }

    /// One deliberation step: the bots holding a slot choose, and a bot whose choice
    /// is to fire fires once. The damage is returned rather than applied, because the
    /// snake is not the bots' to change.
    static func deliberate(_ bots: inout [Bot], slots: [Int], snake: [SIMD3<Double>],
                           world: World) -> Volley {
        var volley = Volley()
        for id in slots {
            guard let index = bots.firstIndex(where: { $0.id == id }) else { continue }
            guard let entry = world.configurations.bot.archetypes[bots[index].archetype.rawValue] else { continue }
            var situation = Deliberation.Situation(plan: world.plan,
                                                   graph: world.graph,
                                                   configuration: world.configurations.bot,
                                                   cellSize: world.configurations.tuning.navigationGraphCellSize)
            // A bot acts on what it knows: one that has not seen the snake has no
            // snake to fire at, flee from or hide behind cover from (FR-BOT-050).
            situation.snake = bots[index].knowsSnake ? snake : []
            situation.allies = bots.filter { $0.squad == bots[index].squad }

            let chosen = Deliberation.choose(for: bots[index], in: situation)
            bots[index].action = chosen
            switch chosen {
            case .fire(let target):
                guard case .snake(let point) = target else { break }
                guard bots[index].ammunition > .zero,
                      Sight.isClear(from: bots[index].eye, to: point, through: world.plan) else { break }
                bots[index].ammunition -= Firing.roundsPerShot
                volley.damage += entry.weaponDamage
                // Drawn for one deliberation period, which is also how long it is
                // until this bot may fire again (FR-VIEW-170).
                volley.shots.append(Shot(from: bots[index].eye, to: point,
                                         squad: bots[index].squad,
                                         left: world.configurations.bot.deliberationPeriod))
            case .reload:
                bots[index].ammunition = entry.magazine
            case .takeCover, .flee, .moveToOrderedZone:
                // The route is the frame's business, and only one is computed per
                // frame (FR-BOT-165).
                bots[index].path = []
            case .heal, .none:
                break
            }
        }
        return volley
    }

    /// One frame: every bot walks what is left of its route.
    ///
    /// At most one route is computed here, and it goes to whoever stands first in
    /// the deliberation order; the rest keep walking what they have until their turn
    /// (FR-BOT-165). Given no order, the bots' own is used, which is what a test
    /// exercising movement alone wants.
    static func walk(_ bots: inout [Bot], seconds: Double, world: World,
                     routeOrder: [Int] = [], holding held: Int? = nil) {
        let cell = world.configurations.tuning.navigationGraphCellSize
        var routed = false
        let queue = routeOrder.isEmpty
            ? Array(bots.indices)
            : routeOrder.compactMap { id in bots.firstIndex { $0.id == id } }
        for index in queue {
            // A bot in the snake's mouth does not walk away from it (FR-SNAKE-090).
            guard bots[index].id != held else { continue }
            guard let goal = destination(of: bots[index].action) else { continue }
            if bots[index].path.isEmpty {
                guard !routed else { continue }
                routed = true
                let here = NavigationGraph.Node(floor: bots[index].floor,
                                                x: Int((bots[index].position.x / cell).rounded()),
                                                z: Int((bots[index].position.z / cell).rounded()))
                bots[index].path = Route.between(here, goal, in: world.graph)
                // Nowhere to go: the action is spent, and the next slot chooses
                // again (FR-BOT-167).
                if bots[index].path.isEmpty { bots[index].action = nil }
            }
            guard let speed = world.configurations.bot.archetypes[bots[index].archetype.rawValue]?.runSpeed
            else { continue }
            advance(&bots[index], by: speed * seconds, cellSize: cell, floorHeight: world.kit.floorHeight)
        }
    }

    /// Where a chosen action sends a bot, if it sends it anywhere.
    static func destination(of action: Action?) -> NavigationGraph.Node? {
        switch action {
        case .takeCover(let node), .moveToOrderedZone(let node), .flee(let node): return node
        case .fire, .reload, .heal, .none: return nil
        }
    }

    /// Walks a bot along its route by the given distance, stopping where the route
    /// runs out.
    private static func advance(_ bot: inout Bot, by distance: Double,
                                cellSize: Double, floorHeight: Double) {
        var left = distance
        while left > Walking.arrived, let next = bot.path.first {
            let there = SIMD3(Double(next.x) * cellSize,
                              Double(next.floor) * floorHeight,
                              Double(next.z) * cellSize)
            let gap = Perception.metres(bot.position, there)
            if gap <= left {
                bot.position = there
                bot.floor = next.floor
                bot.path.removeFirst()
                left -= gap
            } else {
                let step = (there - bot.position) / gap * left
                bot.position += step
                left = .zero
            }
        }
        if bot.path.isEmpty, Execution.destination(of: bot.action) != nil { bot.action = nil }
    }
}
