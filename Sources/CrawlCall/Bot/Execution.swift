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
// implements: FR-BOT-060, FR-BOT-110, FR-BOT-115, FR-BOT-170, FR-BOT-360, FR-BOT-370, FR-BOT-380, FR-BOT-180, FR-BOT-190, INV-BOT-020, FR-VIEW-170, INV-BOT-010, FR-BOT-165, FR-MAP-150, FR-BOT-270, FR-BOT-280, FR-BOT-290, FR-BOT-300, FR-BOT-220, FR-BOT-310, FR-BOT-320, FR-BOT-330, FR-BOT-340
import Foundation

enum Execution {
    /// What one deliberation step did: the damage the snake takes, and the shots that
    /// dealt it, to be drawn where they went (FR-VIEW-170).
    struct Volley: Equatable {
        var damage: Double = .zero
        /// How many of the shots struck the snake.
        var hits = Int.zero
        var shots: [Shot] = []
    }

    /// One deliberation step: the bots holding a slot choose, and a bot whose choice
    /// is to fire fires once. The damage to the snake is returned rather than applied,
    /// because the snake is not the bots' to change; the damage to an enemy bot is
    /// applied here, since the bots are (FR-BOT-060).
    ///
    /// A bot in `interrupted` holds a slot given ahead of the queue (FR-BOT-170): it
    /// chooses as any other, but fires only where a deliberation period has passed
    /// since its last shot, so that being hit is a reason to decide and not a faster
    /// trigger finger (ADR-0057).
    ///
    /// `awareness` is what each squad knows of the snake (FR-SCORE-130); left out, the
    /// snake is taken as known.
    static func deliberate(_ bots: inout [Bot], slots: [Int], world: World, now: Double = .zero,
                           interrupted: Set<Int> = [],
                           awareness: (Squad) -> Awareness = { _ in .confirmed }) -> Volley {
        var volley = Volley()
        // The snake's paths from where each bot takes its head to be, walked once a
        // step for every bot that takes it to be in the same cell (FR-BOT-115).
        var paths: [NavigationGraph.Node: [NavigationGraph.Node: Int]] = [:]
        let cellSize = world.configurations.tuning.navigationGraphCellSize
        for id in slots {
            // A body decides nothing (FR-BOT-320).
            guard let index = bots.firstIndex(where: { $0.id == id }), bots[index].isAlive else { continue }
            guard let entry = world.configurations.bot.archetypes[bots[index].archetype.rawValue] else { continue }
            var situation = Deliberation.Situation(plan: world.plan,
                                                   graph: world.graph,
                                                   configuration: world.configurations.bot,
                                                   cellSize: world.configurations.tuning.navigationGraphCellSize)
            // Come to where it last saw an enemy, or into the enemy's starting area, and
            // found nobody there, it knows that much more (FR-BOT-360).
            let seenNow = Set(bots[index].knowledge.enemies(seenAt: now).map(\.id))
            for (enemy, sighting) in bots[index].knowledge.enemies
            where !seenNow.contains(enemy) && Perception.metres(bots[index].position, sighting.point) <= Idle.arrived {
                bots[index].knowledge.notFound(enemy: enemy, at: now)
            }
            if let area = bots[index].knowledge.enemyStart,
               Perception.metres(bots[index].position, area.centre) <= area.radius {
                bots[index].knowledge.enemyStart = nil
            }
            // A bot acts on what it knows and on nothing else (FR-BOT-220): the snake
            // where it last saw it, and fires only at what it sees now; the cells it
            // may hide or run to are the cells it knows.
            let knowledge = bots[index].knowledge
            situation.snake = knowledge.snakePoints
            situation.inView = knowledge.snake(seenAt: now)
            situation.knows = { knowledge.knows($0) }
            situation.enemies = knowledge.enemyPoints
            situation.enemiesInView = knowledge.enemies(seenAt: now)
            situation.allies = bots.filter { $0.squad == bots[index].squad && $0.isAlive }
            situation.awareness = awareness(bots[index].squad)
            // For a calm squad the snake does not exist beyond the override distance: not
            // as something to fire at, nor as something to hide or run from (FR-BOT-180,
            // FR-BOT-120).
            if situation.awareness == .calm {
                let position = bots[index].position
                let close = { (point: SIMD3<Double>) in
                    Perception.metres(position, point) <= world.configurations.bot.overrideDistance
                }
                situation.snake = situation.snake.filter(close)
                situation.inView = situation.inView.filter(close)
            }
            // Where it believes the enemy to be: the latest sighting, or where they began
            // (FR-BOT-360); ties go to the lower id, so that a match is the same twice over.
            situation.enemyBelief = knowledge.enemies.keys.sorted()
                .compactMap { id in knowledge.enemies[id] }
                .reduce(nil as Knowledge.Sighting?) { best, next in next.time > (best?.time ?? -.infinity) ? next : best }?
                .point ?? knowledge.enemyStart?.centre
            // Where it takes the snake's head to be: the part nearest the head it has
            // seen, as its knowledge numbers them from the head (FR-BOT-110, FR-BOT-115).
            if let head = situation.snake.first {
                situation.snakeHead = head
                if let node = Deliberation.cell(of: head, graph: world.graph, cellSize: cellSize,
                                                floorHeight: world.kit.floorHeight) {
                    if paths[node] == nil { paths[node] = Squads.distances(in: world.graph, from: node) }
                    situation.fromHead = paths[node] ?? [:]
                }
            }

            let chosen = Deliberation.choose(for: bots[index], in: situation)
            bots[index].action = chosen
            switch chosen {
            case .fire(let target):
                let aim: SIMD3<Double>
                var struck: Int?
                switch target {
                case .snake(let point):
                    aim = point
                case .bot(let enemy):
                    guard let other = bots.firstIndex(where: { $0.id == enemy }), bots[other].isAlive else { continue }
                    aim = bots[other].eye
                    struck = other
                }
                guard bots[index].ammunition > .zero,
                      !interrupted.contains(id)
                        || now - bots[index].lastShot >= world.configurations.bot.deliberationPeriod,
                      Sight.isClear(from: bots[index].eye, to: aim, through: world.plan) else { break }
                bots[index].ammunition -= Firing.roundsPerShot
                bots[index].lastShot = now
                if let struck {
                    // A bot with no health left is a body (FR-BOT-320).
                    bots[struck].health = max(.zero, bots[struck].health - entry.weaponDamage)
                    if !bots[struck].isAlive { fall(&bots[struck]) }
                } else {
                    volley.damage += entry.weaponDamage
                    volley.hits += 1
                }
                // Drawn for one deliberation period, which is also how long it is
                // until this bot may fire again (FR-VIEW-170).
                volley.shots.append(Shot(from: bots[index].eye, to: aim,
                                         squad: bots[index].squad,
                                         left: world.configurations.bot.deliberationPeriod))
            case .reload:
                bots[index].ammunition = entry.magazine
            case .takeCover, .flee, .moveToOrderedZone, .advance, .explore:
                // The route is the frame's business, and only one is computed per
                // frame (FR-BOT-165).
                bots[index].path = []
            case .heal, .none:
                break
            }
        }
        return volley
    }

    /// A bot that has died stops where it is: it has nothing left to do, nowhere to go
    /// and no speed (FR-BOT-320).
    static func fall(_ bot: inout Bot) {
        bot.action = nil
        bot.path = []
        bot.speed = .zero
    }

    /// One frame: every bot walks what is left of its route.
    ///
    /// At most one route is computed here, and it goes to whoever stands first in
    /// the deliberation order; the rest keep walking what they have until their turn
    /// (FR-BOT-165). Given no order, the bots' own is used, which is what a test
    /// exercising movement alone wants.
    static func walk(_ bots: inout [Bot], seconds: Double, world: World,
                     routeOrder: [Int] = [], holding held: Int? = nil, now: Double = .zero) {
        let cell = world.configurations.tuning.navigationGraphCellSize
        let before = bots.map(\.position)
        defer {
            // Nobody stands inside anybody (FR-BOT-300), then everybody faces where it
            // went (FR-BOT-280).
            separate(&bots, holding: held, over: world.graph, cellSize: cell, floorHeight: world.kit.floorHeight,
                     radius: world.configurations.tuning.bodyRadius)
            turn(&bots, from: before, seconds: seconds, holding: held, world: world, now: now)
        }
        var routed = false
        let queue = routeOrder.isEmpty
            ? Array(bots.indices)
            : routeOrder.compactMap { id in bots.firstIndex { $0.id == id } }
        for index in queue {
            // A bot in the snake's mouth does not walk away from it (FR-SNAKE-090), and a
            // body does not walk at all (FR-BOT-320).
            guard bots[index].id != held, bots[index].isAlive else { bots[index].speed = .zero; continue }
            // A bot with nowhere to walk has nothing to roll along: it stops (FR-BOT-290).
            guard let goal = destination(of: bots[index].action) else { bots[index].speed = .zero; continue }
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
            guard let top = world.configurations.bot.archetypes[bots[index].archetype.rawValue]?.runSpeed
            else { continue }
            // Up to the run speed and down to a stop at the route's end, no faster
            // than the acceleration allows either way (FR-BOT-290).
            let acceleration = world.configurations.bot.acceleration
            let left = remaining(of: bots[index], over: world.graph, cellSize: cell, floorHeight: world.kit.floorHeight)
            // The fastest it can go this frame and still stop by the end, braking at the
            // acceleration from the next frame on: v = √(2a(d − v·t)), solved for v.
            let change = acceleration * seconds
            let wanted = min(top, (change * change + Geometry.bothSides * acceleration * left).squareRoot() - change)
            bots[index].speed = min(max(wanted, bots[index].speed - change), bots[index].speed + change)
            advance(&bots[index], by: bots[index].speed * seconds, over: world.graph, cellSize: cell,
                    floorHeight: world.kit.floorHeight, radius: world.configurations.tuning.bodyRadius)
            if bots[index].path.isEmpty { bots[index].speed = .zero }
        }
    }

    /// Where a chosen action sends a bot, if it sends it anywhere.
    static func destination(of action: Action?) -> NavigationGraph.Node? {
        switch action {
        case .takeCover(let node), .moveToOrderedZone(let node), .flee(let node),
             .advance(let node), .explore(let node): return node
        case .fire, .reload, .heal, .none: return nil
        }
    }

    /// Walks a bot along its route by the given distance, stopping where the route
    /// runs out.
    private static func advance(_ bot: inout Bot, by distance: Double, over graph: NavigationGraph,
                                cellSize: Double, floorHeight: Double, radius: Double) {
        var left = distance
        while left > Walking.arrived {
            // Straight towards the farthest point of the route the body can walk to
            // over level ground (FR-BOT-270, ADR-0042).
            straighten(&bot, over: graph, cellSize: cellSize, floorHeight: floorHeight, radius: radius)
            guard let next = bot.path.first else { break }
            // At the height of the node's surface: up a flight step by step (FR-MAP-150).
            let there = graph.centre(of: next, cellSize: cellSize, floorHeight: floorHeight)
            let gap = Perception.metres(bot.position, there)
            // Within a hair of the point is at it: braking to a stop closes the last
            // gap in ever smaller steps, and one of them has to be the last.
            if gap <= left + Walking.arrived {
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

    /// What each bot of a squad has seen reaches the rest of it once the squad's delay
    /// has passed since it was seen (FR-BOT-310). Heard at most once a frame, from
    /// every other bot of the squad, the later of two sightings of one thing winning.
    static func share(_ bots: inout [Bot], now: Double, configuration: BotConfiguration) {
        let before = bots
        // The dead neither tell nor hear (FR-BOT-320).
        for index in bots.indices where bots[index].isAlive {
            let squad = bots[index].squad
            guard let delay = configuration.shareDelay[squad.name] else { continue }
            for mate in before where mate.squad == squad && mate.id != bots[index].id && mate.isAlive {
                bots[index].knowledge.hear(mate.knowledge, seenBy: now - delay)
            }
        }
    }

    /// Metres left along a bot's route, from where it stands through every point of it.
    static func remaining(of bot: Bot, over graph: NavigationGraph, cellSize: Double, floorHeight: Double) -> Double {
        var from = bot.position, total = Double.zero
        for node in bot.path {
            let there = graph.centre(of: node, cellSize: cellSize, floorHeight: floorHeight)
            total += Perception.metres(from, there)
            from = there
        }
        return total
    }

    /// Pushes apart every two bots on one floor that stand closer than two body
    /// radii, each by half of what they overlap — all of it for the other where one
    /// is in the snake's mouth — and only onto ground it can stand on (FR-BOT-300).
    static func separate(_ bots: inout [Bot], holding held: Int?, over graph: NavigationGraph,
                         cellSize: Double, floorHeight: Double, radius: Double) {
        let apart = radius * Geometry.bothSides
        for a in bots.indices {
            // A body lies on the floor and is stepped over, not pushed (FR-BOT-320).
            guard bots[a].isAlive else { continue }
            for b in bots.indices where b > a && bots[a].floor == bots[b].floor && bots[b].isAlive {
                let offset = SIMD2(bots[b].position.x - bots[a].position.x, bots[b].position.z - bots[a].position.z)
                let distance = (offset * offset).sum().squareRoot()
                guard distance < apart else { continue }
                // Two on one spot part along a way fixed by who they are, so that the
                // same two always part the same way.
                let away = distance > Turning.noWay
                    ? offset / distance
                    : SIMD2(cos(Double(bots[a].id)), sin(Double(bots[a].id)))
                let overlap = apart - distance
                let aHeld = bots[a].id == held, bHeld = bots[b].id == held
                let aShare = aHeld ? .zero : (bHeld ? Fraction.whole : Geometry.half)
                let bShare = bHeld ? .zero : (aHeld ? Fraction.whole : Geometry.half)
                give(&bots[a], way: -away * overlap * aShare, over: graph, cellSize: cellSize, floorHeight: floorHeight)
                give(&bots[b], way: away * overlap * bShare, over: graph, cellSize: cellSize, floorHeight: floorHeight)
            }
        }
    }

    /// Moves a bot along the ground by `way`, where the ground there holds it at the
    /// height it stands at; leaves it where it is where it does not.
    private static func give(_ bot: inout Bot, way: SIMD2<Double>, over graph: NavigationGraph,
                             cellSize: Double, floorHeight: Double) {
        guard (way * way).sum() > .zero else { return }
        let to = bot.position + SIMD3(way.x, .zero, way.y)
        guard isOpen(from: bot.position, to: to, floor: bot.floor, over: graph, cellSize: cellSize,
                     floorHeight: floorHeight, radius: .zero) else { return }
        bot.position = to
    }

    /// Turns every bot, but one in the snake's mouth, towards what it fires at, or the
    /// way it walked this frame, no faster than the turn speed (FR-BOT-280); a bot
    /// that neither fires nor moved turns to where it looks as it stands.
    ///
    /// A bot standing with nothing to do looks round (FR-BOT-380): once every look-round
    /// interval it turns to a new way, the ways its knowledge puts a threat in first.
    static func turn(_ bots: inout [Bot], from before: [SIMD3<Double>], seconds: Double, holding held: Int?,
                     world: World, now: Double = .zero) {
        let configuration = world.configurations.bot
        let most = configuration.turnSpeed * .pi / Geometry.halfTurnDegrees * max(seconds, .zero)
        // A body turns no more (FR-BOT-320).
        for index in bots.indices where bots[index].id != held && bots[index].isAlive {
            let bot = bots[index]
            var wanted: Double?
            if case .fire(let target) = bot.action {
                switch target {
                case .snake(let point): wanted = Turning.angle(from: bot.position, to: point)
                case .bot(let id): wanted = bot.knowledge.enemies[id].flatMap { Turning.angle(from: bot.position, to: $0.point) }
                }
                bots[index].lookout = nil
            } else if bot.speed > .zero, index < before.count,
                      let went = Turning.angle(from: before[index], to: bot.position) {
                wanted = went
                bots[index].lookout = nil
            } else {
                // Standing: looking where there is something to see, not at a wall a
                // step away (FR-BOT-340), chosen as it stops. With nothing to do it looks
                // round from an interval after that on (FR-BOT-380).
                if bots[index].lookout == nil {
                    bots[index].lookout = lookout(for: bot, world: world)
                    bots[index].lastLookRound = now
                }
                if bot.action == nil, now - bots[index].lastLookRound >= configuration.lookRoundInterval {
                    bots[index].lookout = lookRound(for: bot, world: world)
                    bots[index].lastLookRound = now
                }
                wanted = bots[index].lookout
            }
            guard let wanted else { continue }
            bots[index].facing = Turning.toward(wanted, from: bot.facing, by: most)
        }
    }

    /// Which way a standing bot looks (FR-BOT-340): the way it faces, while as much
    /// open ground as `Looking.openEnough` lies before it; otherwise, of the ways round
    /// it, the one with the most open ground before it, the nearest to the way it faces
    /// among equals. Open is what the bot knows: a cell is in the way where it lies
    /// outside the building's outline, or where the bot has seen it and nobody can
    /// stand in it; a cell it has not seen is open until it has (ADR-0032).
    static func lookout(for bot: Bot, world: World) -> Double {
        func open(_ angle: Double) -> Double { openGround(for: bot, towards: angle, world: world) }
        guard open(bot.facing) < Looking.openEnough else { return bot.facing }
        var best = (angle: bot.facing, open: open(bot.facing), turn: Double.zero)
        for way in 0..<Looking.ways {
            let angle = Double(way) / Double(Looking.ways) * .pi * Geometry.bothSides
            let seen = open(angle)
            let turn = abs(atan2(sin(angle - bot.facing), cos(angle - bot.facing)))
            if seen > best.open + Geometry.samePosition
                || (abs(seen - best.open) <= Geometry.samePosition && turn < best.turn) {
                best = (angle, seen, turn)
            }
        }
        return best.angle
    }

    /// How much open ground lies before a bot the given way, in metres, up to its
    /// detection range: open as the bot knows it (FR-BOT-340).
    static func openGround(for bot: Bot, towards angle: Double, world: World) -> Double {
        let cell = world.configurations.tuning.navigationGraphCellSize
        let range = world.configurations.bot.archetypes[bot.archetype.rawValue]?.detectionRange ?? .zero
        let along = SIMD2(sin(angle), cos(angle))
        let step = cell * Walking.lookStep
        var metres = step
        while metres <= range {
            let point = SIMD2(bot.position.x, bot.position.z) + along * metres
            let node = NavigationGraph.Node(floor: bot.floor, x: Int((point.x / cell).rounded()),
                                            z: Int((point.y / cell).rounded()))
            let blocked = !bot.knowledge.outline.contains(node)
                || (bot.knowledge.knows(node) && !world.graph.isWalkable(node))
            if blocked { return metres - step }
            metres += step
        }
        return range
    }

    /// Which way a bot standing with nothing to do turns to next (FR-BOT-380): of the
    /// ways round it with as much open ground before it as `Looking.openEnough` — or,
    /// where none has, of them all — one outside the half of its field of view it looks
    /// over now, the way nearest a threat its knowledge holds counting `Idle.threatShare`
    /// times as much as how far round from where it looks the way is. Where it looks is
    /// where it last turned to look, which it may not have finished turning to. A threat
    /// is where it last saw or was told of the snake or an enemy bot, and the enemy's
    /// starting area while it has not been there (ADR-0059).
    static func lookRound(for bot: Bot, world: World) -> Double {
        let knowledge = bot.knowledge
        let threats = (knowledge.snakePoints + knowledge.enemyPoints + [knowledge.enemyStart?.centre].compactMap { $0 })
            .compactMap { Turning.angle(from: bot.position, to: $0) }
        let half = world.configurations.bot.fieldOfView * Geometry.half * .pi / Geometry.halfTurnDegrees
        let looking = bot.lookout ?? bot.facing
        func off(_ a: Double, _ b: Double) -> Double { abs(atan2(sin(a - b), cos(a - b))) }
        let ways = (0..<Looking.ways).map { Double($0) / Double(Looking.ways) * .pi * Geometry.bothSides }
        let open = ways.filter { openGround(for: bot, towards: $0, world: world) >= Looking.openEnough }
        var best: (angle: Double, worth: Double)?
        for angle in (open.isEmpty ? ways : open) where off(angle, looking) > half {
            let towardThreat = threats.map { cos(off(angle, $0)) }.max() ?? .zero
            let worth = Idle.threatShare * towardThreat + off(angle, looking) / .pi
            if best == nil || worth > best!.worth + Geometry.samePosition { best = (angle, worth) }
        }
        return best?.angle ?? looking
    }

    /// Drops the next point of a bot's route while the one after it can be walked to
    /// in a straight line from where the bot stands (FR-BOT-270, ADR-0042).
    static func straighten(_ bot: inout Bot, over graph: NavigationGraph, cellSize: Double,
                           floorHeight: Double, radius: Double) {
        while bot.path.count > Distances.oneMore,
              let after = bot.path.dropFirst().first,
              isOpen(from: bot.position, to: graph.centre(of: after, cellSize: cellSize, floorHeight: floorHeight),
                     floor: bot.floor, over: graph, cellSize: cellSize, floorHeight: floorHeight, radius: radius) {
            bot.path.removeFirst()
        }
    }

    /// Whether a body of `radius` can walk straight from one point to another over
    /// level ground: along the line and along two lines beside it at the body's
    /// radius, sampled every quarter cell, every point is over a cell of `floor` the
    /// graph holds, at the height the walk starts at.
    static func isOpen(from start: SIMD3<Double>, to end: SIMD3<Double>, floor: Int, over graph: NavigationGraph,
                       cellSize: Double, floorHeight: Double, radius: Double) -> Bool {
        guard abs(end.y - start.y) <= Geometry.samePosition else { return false }
        let run = SIMD2(end.x - start.x, end.z - start.z)
        let length = (run.x * run.x + run.y * run.y).squareRoot()
        guard length > Walking.arrived else { return true }
        let along = run / length
        let across = SIMD2(-along.y, along.x) * radius
        let step = cellSize * Walking.lookStep
        var metres = Double.zero
        while true {
            let centre = SIMD2(start.x, start.z) + along * min(metres, length)
            for point in [centre, centre + across, centre - across] {
                let cell = NavigationGraph.Node(floor: floor, x: Int((point.x / cellSize).rounded()),
                                                z: Int((point.y / cellSize).rounded()))
                guard graph.isWalkable(cell),
                      abs(graph.height(of: cell, floorHeight: floorHeight) - start.y) <= Geometry.samePosition
                else { return false }
            }
            if metres >= length { return true }
            metres += step
        }
    }
}
