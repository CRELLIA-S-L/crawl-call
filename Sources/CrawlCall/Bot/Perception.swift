// What a bot sees, and so comes to know (ADR-0032): the snake (FR-BOT-050), the enemy
// (FR-BOT-240) and the map (FR-BOT-230), each written into its knowledge with when.
//
// "In view" is three things: within the detection range, within the field of view —
// a cone round the way the bot faces (FR-BOT-280), as wide as the configuration's
// angle — and with nothing in the way. A bot does not see with the back of its head.
//
// implements: FR-BOT-050, FR-BOT-230, FR-BOT-240
import Foundation

enum Perception {
    /// Writes into every bot's knowledge each part of the snake it can see, where and
    /// when, the latest sighting of a part replacing the one before (FR-BOT-050).
    ///
    /// Any part counts, which is the point of the requirement: a snake whose head is
    /// behind a crate and whose tail is not has been seen.
    static func notice(_ bots: inout [Bot], snake: [SIMD3<Double>],
                       plan: ScenePlan, configuration: BotConfiguration, now: Double = .zero) {
        for index in bots.indices {
            guard let range = configuration.archetypes[bots[index].archetype.rawValue]?.detectionRange
            else { continue }
            for (part, point) in snake.enumerated()
            where sees(point, from: bots[index], within: range, plan: plan, configuration: configuration) {
                bots[index].knowledge.snake[part] = .init(point: point, time: now)
            }
        }
    }

    /// Writes into every bot's knowledge each enemy bot it can see, where and when
    /// (FR-BOT-240). What it looks at is the enemy's eyes: its head, the part that
    /// shows over cover first.
    static func noticeEnemies(_ bots: inout [Bot], plan: ScenePlan, configuration: BotConfiguration, now: Double) {
        let everyone = bots
        for index in bots.indices {
            guard let range = configuration.archetypes[bots[index].archetype.rawValue]?.detectionRange
            else { continue }
            for enemy in everyone where enemy.squad != bots[index].squad
                && sees(enemy.eye, from: bots[index], within: range, plan: plan, configuration: configuration) {
                bots[index].knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
            }
        }
    }

    /// Writes into a bot's knowledge every cell of the map round it that it can see,
    /// with what stands in it and when (FR-BOT-230). A cell is looked at on its side
    /// nearer the bot, just off the ground, so that a wall is seen by its face and a
    /// floor by its near edge.
    static func lookAtMap(_ bot: inout Bot, world: World, modules: [NavigationGraph.Node: String], now: Double) {
        let configuration = world.configurations.bot
        guard let range = configuration.archetypes[bot.archetype.rawValue]?.detectionRange else { return }
        let cell = world.configurations.tuning.navigationGraphCellSize
        let reach = Int((range / cell).rounded(.up))
        let column = Int((bot.position.x / cell).rounded()), row = Int((bot.position.z / cell).rounded())
        for floor in world.graph.floors {
            for x in (column - reach)...(column + reach) {
                for z in (row - reach)...(row + reach) {
                    let node = NavigationGraph.Node(floor: floor, x: x, z: z)
                    let walkable = world.graph.isWalkable(node)
                    guard walkable || modules[node] != nil else { continue }
                    let ground = walkable
                        ? world.graph.height(of: node, floorHeight: world.kit.floorHeight)
                        : Double(floor) * world.kit.floorHeight
                    let centre = SIMD3(Double(x) * cell, ground, Double(z) * cell)
                    let back = SIMD2(bot.position.x - centre.x, bot.position.z - centre.z)
                    let length = (back * back).sum().squareRoot()
                    let near = length > Turning.noWay ? back / length * min(cell * Looking.nearSide, length) : .zero
                    let point = SIMD3(centre.x + near.x, ground + Looking.offGround, centre.z + near.y)
                    guard sees(point, from: bot, within: range, plan: world.plan, configuration: configuration)
                    else { continue }
                    bot.knowledge.cells[node] = .init(stands: modules[node], time: now)
                }
            }
        }
        bot.lastLook = now
    }

    /// Which module stands in each cell of a map, for the map's sightings.
    static func modules(of map: MapSpecification) -> [NavigationGraph.Node: String] {
        var modules: [NavigationGraph.Node: String] = [:]
        for placement in map.placements {
            modules[NavigationGraph.Node(floor: placement.floor, x: placement.x, z: placement.z)] = placement.module
        }
        return modules
    }

    /// Whether a bot sees a point: within its range, where it stands; within its field
    /// of view; and with nothing in the way from its eyes, over whatever stands lower
    /// than the line (ADR-0022).
    static func sees(_ point: SIMD3<Double>, from bot: Bot, within range: Double, plan: ScenePlan,
                     configuration: BotConfiguration) -> Bool {
        metres(bot.position, point) <= range
            && isInFieldOfView(point, of: bot, degrees: configuration.fieldOfView)
            && Sight.isClear(from: bot.eye, to: point, through: plan)
    }

    /// Whether a point lies within a bot's field of view: no farther round from the way
    /// it faces than half the field's angle. A point straight above or below it has no
    /// way round, and is in view.
    static func isInFieldOfView(_ point: SIMD3<Double>, of bot: Bot, degrees: Double) -> Bool {
        guard let towards = Turning.angle(from: bot.position, to: point) else { return true }
        let off = abs(atan2(sin(towards - bot.facing), cos(towards - bot.facing)))
        return off <= degrees * Geometry.half * .pi / Geometry.halfTurnDegrees
    }

    static func metres(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = b - a
        return (d * d).sum().squareRoot()
    }
}
