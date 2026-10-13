// What the bots actually do. Two clocks meet here: deliberation, which runs on its
// own fixed step (FR-BOT-150), and execution, which runs every frame for every
// living bot (INV-BOT-010) — a decision arriving late goes unnoticed, a body moving
// at seven frames a second does not.
//
// A shot is fired by the deliberation step rather than by the frame, so that a bot
// firing at sixty frames a second and one firing at thirty deal the same damage a
// second. How often it may fire is its weapon's own (FR-BOT-450) and the step is the
// floor under it: a weapon quicker than a slot fires once a slot, one slower than a
// slot is aimed through the slots it has to wait out. Until 2026-10-12 the period was
// the cadence, because no requirement gave a weapon a rate of fire.
//
// Each weapon counts that time from its own last use and not from the bot's last act
// (FR-BOT-610): the clock is in the arms, one entry a use, and what is left on the bot
// is the one act a slot holds it to (FR-BOT-170). Until 2026-10-13 both were one field,
// and firing pushed the knife's next strike away.
//
// file implements: FR-BOT-550, FR-BOT-560, FR-BOT-570, FR-BOT-580, FR-BOT-600, FR-BOT-610, FR-BOT-450, FR-BOT-470, FR-BOT-510, FR-BOT-520, FR-BOT-167, FR-BOT-060, FR-BOT-110, FR-BOT-115, FR-BOT-170, FR-BOT-360, FR-BOT-370, FR-BOT-380, FR-BOT-180, FR-BOT-190, INV-BOT-020, INV-BOT-010, FR-BOT-165, FR-MAP-150, FR-BOT-270, FR-BOT-280, FR-BOT-290, FR-BOT-300, FR-BOT-220, FR-BOT-310, FR-BOT-320, FR-BOT-330, FR-BOT-340, FR-BOT-420, FR-BOT-425, FR-BOT-430, FR-CMD-030, FR-CMD-040
import Foundation

enum Execution {
    /// What one deliberation step did: the rounds it fired, to fly from the next frame
    /// on (FR-BOT-060).
    struct Volley: Equatable {
        var rounds: [Round] = []
        /// The grenades thrown in it, to burn their fuses down from the next frame on
        /// (FR-BOT-470).
        var grenades: [Thrown] = []
        /// What the knives struck of the snake in it (FR-BOT-510): a knife deals its
        /// damage where it stands and sends nothing flying, and the snake is not the
        /// squads' to change, so it is carried out to the match as a round's damage is.
        var struck = Flight.Struck()
    }

    /// One deliberation step: the bots holding a slot choose, and a bot whose choice
    /// is to fire sends one round, which is returned to fly (FR-BOT-060); what it
    /// strikes is the flight's business (FR-BOT-400).
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
                           awareness: (Squad) -> Awareness = { _ in .confirmed },
                           command: (Squad) -> SquadCommand? = { _ in nil }) -> Volley {
        var volley = Volley()
        // The snake's paths from where each bot takes its head to be, walked once a
        // step for every bot that takes it to be in the same cell (FR-BOT-115).
        var paths: [NavigationGraph.Node: [NavigationGraph.Node: Int]] = [:]
        let cellSize = world.configurations.tuning.navigationGraphCellSize
        for id in slots {
            // A body decides nothing (FR-BOT-320).
            guard let index = bots.firstIndex(where: { $0.id == id }), bots[index].isAlive else { continue }
            // An archetype the configuration knows nothing of decides nothing either:
            // what a bot is made of is read from its entry (IF-BOT-010), and the
            // numbers of what it fires from its arms (FR-BOT-450).
            guard world.configurations.bot.archetypes[bots[index].archetype.rawValue] != nil else { continue }
            var situation = Deliberation.Situation(plan: world.plan,
                                                   graph: world.graph,
                                                   configuration: world.configurations.bot,
                                                   cellSize: world.configurations.tuning.navigationGraphCellSize)
            situation.now = now
            situation.bodyRadius = world.configurations.tuning.bodyRadius
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

            // What its commander last told the squad, if it has one: what to worry about,
            // which ranks what it fires at (FR-CMD-030), and which part of the arena the
            // order names, which every position is then scored against (FR-BOT-116).
            //
            // An order that says where the enemy is tells a bot that has seen none: being
            // told is one of the two ways FR-BOT-360 says a bot comes to believe
            // anything, and a bot with a sighting of its own keeps it, because its own
            // eyes are nearer the truth than a word from seven seconds ago.
            if let standing = command(bots[index].squad) {
                situation.priority = standing.threat
                situation.arenaSpan = Perception.metres(world.plan.bounds.lowest, world.plan.bounds.highest)
                if let part = standing.place {
                    let middle = Places.middle(of: part, in: world.plan.bounds)
                    situation.orderedPart = middle
                    if standing.order.namesTheEnemy, knowledge.enemies.isEmpty {
                        situation.enemyBelief = middle
                    }
                }
                situation.orderedZone = Deliberation.ordered(for: bots[index], in: situation)
            }

            let chosen = Deliberation.choose(for: bots[index], in: situation)
            let before = bots[index].action
            bots[index].action = chosen
            // Anything but the reload it was in the middle of loses it, and starting
            // again starts from the beginning (FR-BOT-550): a bot that could duck out,
            // fire and duck back without losing the reload is a bot for which reloading
            // costs nothing again.
            if case .reload(let slot) = chosen, bots[index].reloading?.slot == slot {} else {
                bots[index].reloading = nil
            }
            // The slot the failed route earned has been taken, and the exclusion is
            // spent with it: the next slot after scores that action again (FR-BOT-167).
            bots[index].unreachable = nil
            switch chosen {
            case .fire(let target, let slot):
                // Where the line of fire is judged from: the ground under the part of the
                // snake it sees, as it sees it (FR-BOT-050), or the enemy's eyes.
                // It fires only at what it sees now (FR-BOT-060); a target it knows of and
                // does not see is one it goes out to fire at from beside cover (ADR-0063).
                let sighted: SIMD3<Double>
                let seen: Bool
                switch target {
                case .snake(let point):
                    sighted = point
                    seen = situation.inView.contains(point)
                case .bot(let enemy):
                    guard let other = bots.firstIndex(where: { $0.id == enemy }), bots[other].isAlive else { continue }
                    sighted = bots[other].eye
                    seen = situation.enemiesInView.contains { $0.id == enemy }
                }
                guard let aim = Deliberation.aim(at: target, from: bots[index], in: situation) else { continue }
                place(&bots[index], at: target, aim: aim, before: before, in: situation, now: now)
                // The weapon it chose decides how often it may fire and what the round
                // deals (FR-BOT-450). The cadence is its own guard and not the slot's:
                // a weapon slower than the deliberation period is aimed for a slot or
                // two before it goes off, and a bot given a slot ahead of the queue
                // still fires no faster than once a period, which is what keeps an
                // interrupt from being extra shots (FR-BOT-170, ADR-0057).
                let firearm = bots[index].arms[slot]
                guard seen, bots[index].arms.ready(.shot(slot), at: now),
                      !interrupted.contains(id)
                        || now - bots[index].lastShot >= world.configurations.bot.deliberationPeriod,
                      Sight.isClear(from: bots[index].eye, to: sighted, through: world.plan) else { break }
                bots[index].arms.spend(.shot(slot), at: now)
                bots[index].lastShot = now
                // Sent at the point where the target is now; what it strikes is where
                // it flies (FR-BOT-060, FR-BOT-400).
                if let round = Round(shooter: bots[index].id, squad: bots[index].squad, from: bots[index].eye,
                                     towards: aim, damage: firearm.numbers.damage) {
                    volley.rounds.append(round)
                }
            case .throwGrenade(let target):
                // Thrown at what it sees, as a round is sent at what it sees
                // (FR-BOT-060): the grenade lies where it was thrown and goes off when
                // its fuse has run out (FR-BOT-470). Where it may be thrown at all was
                // settled when the action was scored (FR-BOT-500).
                let seen: Bool
                let sighted: SIMD3<Double>
                switch target {
                case .snake(let point):
                    sighted = point
                    seen = situation.inView.contains(point)
                case .bot(let enemy):
                    guard let other = bots.firstIndex(where: { $0.id == enemy }), bots[other].isAlive else { continue }
                    sighted = bots[other].eye
                    seen = situation.enemiesInView.contains { $0.id == enemy }
                }
                guard let where_ = Deliberation.aim(at: target, from: bots[index], in: situation) else { continue }
                // A throw is an act like a shot and costs the slot: a bot given one
                // ahead of the queue does not get an extra grenade out of it
                // (FR-BOT-170, ADR-0057).
                guard seen, bots[index].arms.ready(.throwGrenade, at: now),
                      !interrupted.contains(id)
                        || now - bots[index].lastShot >= world.configurations.bot.deliberationPeriod,
                      Sight.isClear(from: bots[index].eye, to: sighted, through: world.plan) else { break }
                bots[index].arms.spend(.throwGrenade, at: now)
                bots[index].lastShot = now
                // It leaves the hand along an arc that would land it where it was aimed
                // (FR-BOT-580) rather than lying there from the first frame.
                let numbers = bots[index].arms.grenades.numbers
                volley.grenades.append(
                    Thrown(thrower: bots[index].id, squad: bots[index].squad,
                           position: bots[index].eye,
                           velocity: Blast.throwing(from: bots[index].eye, at: where_, range: numbers.throwRange,
                                                    gravity: world.configurations.tuning.dropGravity),
                           numbers: numbers, fuse: numbers.fuseTime))
                bots[index].post = nil
                bots[index].refuge = nil
                bots[index].postTarget = nil
            case .strike(let target):
                // At the reach of an arm, with no line of fire asked for: there is
                // nothing to stand in the way at that distance (FR-BOT-510). It still
                // has to be what the bot sees, as everything a bot acts on is
                // (FR-BOT-220), and it still costs the slot.
                // How often it may be swung is the knife's own, the way a weapon's
                // cadence is its own (FR-BOT-450): without it the knife would be swung
                // at every slot, which at the reach of an arm is the deadliest thing in
                // the game by a factor of ten.
                guard let knife = bots[index].arms.knife,
                      bots[index].arms.ready(.strike, at: now),
                      !interrupted.contains(id)
                        || now - bots[index].lastShot >= world.configurations.bot.deliberationPeriod else { break }
                bots[index].arms.spend(.strike, at: now)
                bots[index].lastShot = now
                switch target {
                case .snake(let point):
                    guard situation.inView.contains(point),
                          Perception.metres(bots[index].position, point) <= knife.numbers.reach else { break }
                    volley.struck.damage += knife.numbers.damage
                    volley.struck.hits += 1
                case .bot(let enemy):
                    guard let other = bots.firstIndex(where: { $0.id == enemy }), bots[other].isAlive,
                          situation.enemiesInView.contains(where: { $0.id == enemy }),
                          Perception.metres(bots[index].position, bots[other].position) <= knife.numbers.reach
                    else { break }
                    bots[other].health = max(.zero, bots[other].health - knife.numbers.damage)
                    if !bots[other].isAlive { fall(&bots[other]) }
                }
            case .throwKnife(let target):
                // Thrown, it flies and strikes what it meets like anything else sent
                // through the air (FR-BOT-400, FR-BOT-405); and it is gone whether it
                // struck or not (FR-BOT-520).
                let seen: Bool
                switch target {
                case .snake(let point): seen = situation.inView.contains(point)
                case .bot(let enemy): seen = situation.enemiesInView.contains { $0.id == enemy }
                }
                guard let knife = bots[index].arms.knife, seen,
                      bots[index].arms.ready(.throwKnife, at: now),
                      let flight = Deliberation.aim(at: target, from: bots[index], in: situation),
                      !interrupted.contains(id)
                        || now - bots[index].lastShot >= world.configurations.bot.deliberationPeriod else { break }
                bots[index].lastShot = now
                bots[index].arms.spend(.throwKnife, at: now)
                if let round = Round(shooter: bots[index].id, squad: bots[index].squad, from: bots[index].eye,
                                     towards: flight, damage: knife.numbers.damage) {
                    volley.rounds.append(round)
                }
            case .reload(let slot):
                // The clock starts when the reload is chosen and runs while nothing else
                // is chosen (FR-BOT-550); choosing the same reload again at the next slot
                // keeps the one already running, and the magazine is filled by the frame
                // that finds the time up.
                if bots[index].reloading?.slot != slot {
                    bots[index].reloading = Reload(slot: slot,
                                                   due: now + bots[index].arms[slot].numbers.reloadTime)
                }
                // Behind the cover it fired from beside, where it has one: it goes into
                // the hidden cell and reloads there (FR-BOT-425).
                if bots[index].post != nil, bots[index].refuge != nil {
                    if case .reload = before {} else { bots[index].path = [] }
                } else {
                    bots[index].post = nil
                    bots[index].refuge = nil
                    bots[index].postTarget = nil
                }
            case .takeCover, .flee, .moveToOrderedZone, .advance, .explore, .close:
                // The route is the frame's business, and only one is computed per
                // frame (FR-BOT-165).
                bots[index].path = []
                bots[index].post = nil
                bots[index].refuge = nil
                bots[index].postTarget = nil
            case .heal, .none:
                bots[index].post = nil
                bots[index].refuge = nil
                bots[index].postTarget = nil
            }
        }
        return volley
    }

    /// Where a bot about to fire at `aim` fires from (FR-BOT-420): the cell beside
    /// cover it already has while it still has a line of fire from there and the cell
    /// behind it is still hidden, or the nearest there is now. One that finds none
    /// fires on the move (FR-BOT-430), and looks again once the strafing interval has
    /// passed since it last looked.
    static func place(_ bot: inout Bot, at target: Target, aim: SIMD3<Double>, before: Action?,
                      in situation: Deliberation.Situation, now: Double) {
        let wasFiring: Bool
        if case .fire = before { wasFiring = true } else { wasFiring = false }
        let wasStrafing = wasFiring && bot.post == nil
        if let post = bot.post, let refuge = bot.refuge,
           Sight.isClear(from: Deliberation.centre(of: post, in: situation) + SIMD3(.zero, bot.eyeHeight, .zero),
                         to: aim, through: situation.plan),
           !Deliberation.isWatched(refuge, for: bot, in: situation) {
            if !wasFiring { bot.path = [] }
            bot.postTarget = target
            return
        }
        if bot.post != nil || now - bot.lastPostSearch >= situation.configuration.strafingInterval {
            let found = Deliberation.post(for: bot, aim: aim, in: situation)
            bot.lastPostSearch = now
            if found?.post != bot.post || !wasFiring { bot.path = [] }
            bot.post = found?.post
            bot.refuge = found?.refuge
        }
        bot.postTarget = bot.post == nil ? nil : target
        if bot.post == nil, !wasStrafing { bot.strafeSince = now }
    }

    /// The cell a bot stands in.
    static func cell(of bot: Bot, world: World) -> NavigationGraph.Node {
        let size = world.configurations.tuning.navigationGraphCellSize
        return NavigationGraph.Node(floor: bot.floor, x: Int((bot.position.x / size).rounded()),
                                    z: Int((bot.position.z / size).rounded()))
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
            guard let goal = destination(of: bots[index]) else {
                // Firing with no cell beside cover, it keeps moving (FR-BOT-430).
                if case .fire = bots[index].action {
                    strafe(&bots[index], seconds: seconds, world: world, now: now)
                } else {
                    bots[index].speed = .zero
                }
                continue
            }
            // Already where it fires from, or where it reloads (FR-BOT-420, FR-BOT-425); a
            // bot already where it was going has arrived, which spends an action that
            // travels, and the next slot chooses again. A reload does not travel: it
            // stands in the cell it ducked into until its own time is up (FR-BOT-550).
            // Arriving is not being cut off: the graph holds a route of no steps, and
            // nothing is excluded for it (FR-BOT-167).
            if bots[index].path.isEmpty, Execution.cell(of: bots[index], world: world) == goal {
                bots[index].speed = .zero
                if travels(bots[index].action) { bots[index].action = nil }
                continue
            }
            // Its way's end taken by another bot, and it up against that bot: it is as near
            // as it will get, since bots do not pass through one another (FR-BOT-300), and
            // walking on into it would have the two push each other back and forth for as
            // long as it wanted the cell.
            if isCrowdedOut(from: goal, bot: index, among: bots, world: world) {
                bots[index].path = []
                bots[index].speed = .zero
                if travels(bots[index].action) { bots[index].action = nil }
                continue
            }
            if bots[index].path.isEmpty {
                guard !routed else { continue }
                routed = true
                let here = NavigationGraph.Node(floor: bots[index].floor,
                                                x: Int((bots[index].position.x / cell).rounded()),
                                                z: Int((bots[index].position.z / cell).rounded()))
                bots[index].path = Route.between(here, goal, in: world.graph)
                // Nowhere to go: the action is spent and remembered, so that the slot
                // this earns the bot scores everything but that action (FR-BOT-167).
                if bots[index].path.isEmpty {
                    bots[index].unreachable = bots[index].action
                    bots[index].action = nil
                }
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

    /// Whether another living bot stands on the cell a bot is making for — within a body
    /// radius of its centre — and the bot is up against it, no further from it than two
    /// radii and a touch.
    static func isCrowdedOut(from goal: NavigationGraph.Node, bot index: Int, among bots: [Bot], world: World) -> Bool {
        let radius = world.configurations.tuning.bodyRadius
        let centre = world.graph.centre(of: goal, cellSize: world.configurations.tuning.navigationGraphCellSize,
                                        floorHeight: world.kit.floorHeight)
        return bots.indices.contains { other in
            other != index && bots[other].isAlive && bots[other].floor == goal.floor
                && Perception.metres(bots[other].position, centre) <= radius
                && Perception.metres(bots[other].position, bots[index].position)
                    <= radius * Geometry.bothSides + Walking.touching
        }
    }

    /// Every bot whose reload is due: the magazine is filled, a spare magazine is spent
    /// for it (FR-BOT-550, FR-BOT-560), and the act is over, so the next slot chooses
    /// afresh. Run every frame, because a reload ends where its own time ends and not
    /// at the deliberation step that happens to follow.
    static func fill(_ bots: inout [Bot], now: Double) {
        for index in bots.indices {
            guard let reloading = bots[index].reloading else { continue }
            guard bots[index].isAlive else { bots[index].reloading = nil; continue }
            guard case .reload(let slot) = bots[index].action, slot == reloading.slot else {
                bots[index].reloading = nil
                continue
            }
            guard now >= reloading.due else { continue }
            bots[index].arms.fill(slot)
            bots[index].reloading = nil
            bots[index].action = nil
        }
    }

    /// Moves a bot that fires with no cell beside cover across its line of fire, at the
    /// strafing speed, gathered and shed at the acceleration (FR-BOT-290): the way it
    /// goes turns back once the strafing interval has passed, and where the ground it
    /// would move onto does not hold it (FR-BOT-430).
    static func strafe(_ bot: inout Bot, seconds: Double, world: World, now: Double) {
        guard case .fire(let target, _) = bot.action else { return }
        let towards: SIMD3<Double>?
        switch target {
        case .snake(let point): towards = point
        case .bot(let id): towards = bot.knowledge.enemies[id]?.point
        }
        let configuration = world.configurations.bot
        guard let towards else { bot.speed = .zero; return }
        let line = SIMD2(towards.x - bot.position.x, towards.z - bot.position.z)
        let length = (line * line).sum().squareRoot()
        guard length > Turning.noWay else { bot.speed = .zero; return }
        if now - bot.strafeSince >= configuration.strafingInterval {
            bot.strafe = -bot.strafe
            bot.strafeSince = now
        }
        let change = configuration.acceleration * max(seconds, .zero)
        bot.speed = min(max(configuration.strafingSpeed, bot.speed - change), bot.speed + change)
        let across = SIMD2(line.y, -line.x) / length * bot.strafe
        let step = across * bot.speed * seconds
        let to = bot.position + SIMD3(step.x, .zero, step.y)
        let cell = world.configurations.tuning.navigationGraphCellSize
        if isOpen(from: bot.position, to: to, floor: bot.floor, over: world.graph, cellSize: cell,
                  floorHeight: world.kit.floorHeight, radius: world.configurations.tuning.bodyRadius) {
            bot.position = to
        } else {
            bot.strafe = -bot.strafe
            bot.strafeSince = now
            bot.speed = .zero
        }
    }

    /// Where a bot's chosen action sends it, if it sends it anywhere: a bot firing
    /// goes to where it fires from beside cover (FR-BOT-420), one reloading behind it
    /// to the hidden cell (FR-BOT-425).
    static func destination(of bot: Bot) -> NavigationGraph.Node? {
        switch bot.action {
        case .takeCover(let node), .moveToOrderedZone(let node), .flee(let node),
             .advance(let node), .explore(let node), .close(_, let node): return node
        case .fire: return bot.post
        case .reload: return bot.post == nil ? nil : bot.refuge
        case .throwGrenade, .strike, .throwKnife, .heal, .none: return nil
        }
    }

    /// Whether an action is over once the bot has walked its way: going somewhere is,
    /// firing from somewhere and reloading behind cover are not.
    static func travels(_ action: Action?) -> Bool {
        switch action {
        case .takeCover, .moveToOrderedZone, .flee, .advance, .explore, .close: return true
        case .fire, .throwGrenade, .strike, .throwKnife, .reload, .heal, .none: return false
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
            // A point on the way, not its end, is passed once the body is over it: a bot
            // pushed off it by another (FR-BOT-300) does not turn back to stand on it, and
            // two making for one such point do not push each other round it.
            while bot.path.count > Distances.oneMore, let next = bot.path.first, next.floor == bot.floor,
                  Perception.metres(bot.position, graph.centre(of: next, cellSize: cellSize,
                                                               floorHeight: floorHeight)) <= radius {
                bot.path.removeFirst()
            }
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
        if bot.path.isEmpty, Execution.travels(bot.action) { bot.action = nil }
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
            // What it is shooting at or throwing at is what it faces.
            var aimedAt: Target?
            switch bot.action {
            case .fire(let target, _), .throwGrenade(let target),
                 .strike(let target), .throwKnife(let target): aimedAt = target
            default: aimedAt = nil
            }
            if let aimedAt {
                switch aimedAt {
                case .snake(let point): wanted = Turning.angle(from: bot.position, to: point)
                case .bot(let id): wanted = bot.knowledge.enemies[id].flatMap { Turning.angle(from: bot.position, to: $0.point) }
                }
                bots[index].lookout = nil
            } else if bot.speed > .zero, let way = heading(of: bot, world: world) {
                // Walking a route: the way the route goes, not the way the frame moved it,
                // which a squadmate's push turns this way and that (FR-BOT-300).
                wanted = way
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

    /// The way a walking bot's route goes from where it is: towards the first point of
    /// it more than a cell away, or its last point where none is. A point nearer than
    /// that swings round the bot at every push it is given, and a bot facing it would
    /// turn back and forth as it went. Nil with no route, or at its end.
    static func heading(of bot: Bot, world: World) -> Double? {
        let cell = world.configurations.tuning.navigationGraphCellSize
        let points = bot.path.map { world.graph.centre(of: $0, cellSize: cell, floorHeight: world.kit.floorHeight) }
        guard let last = points.last else { return nil }
        let ahead = points.first { Perception.metres(bot.position, $0) > cell } ?? last
        return Turning.angle(from: bot.position, to: ahead)
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
