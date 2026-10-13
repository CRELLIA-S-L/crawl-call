// How a bot decides. Every action it could take is scored, and the highest wins
// (FR-BOT-080); the score of each is the bot's personality applied to what it can
// see (FR-BOT-090).
//
// The inputs are the ones FR-BOT-080 names — what the bot knows of the snake and of
// the enemy, the order it was given, the danger it stands in, its health, its five
// personality weights, and what it has to fight with — and the terms below are written
// so that each of them can be varied on its own and the choice watched to move, which
// is what its rationale asks of a test. The last of them is four weapons rather than
// one magazine (FR-BOT-440): each firearm that has a round and reaches is scored on
// its own numbers (FR-BOT-450, FR-BOT-460).
//
// The weight of one term against another is tuning, and is read from the bot
// configuration (IF-BOT-010), as is how much an unhurt bot fears the snake
// (FR-BOT-210). What shapes each term — a share, a whole — is in `Utility`.
//
// file implements: FR-BOT-530, FR-BOT-540, FR-BOT-167, FR-BOT-116, FR-BOT-460, FR-BOT-450, FR-BOT-470, FR-BOT-500, FR-BOT-510, FR-BOT-520, FR-BOT-080, FR-BOT-090, FR-BOT-110, FR-BOT-115, FR-BOT-118, FR-BOT-119, FR-BOT-360, FR-BOT-370, FR-BOT-120, FR-BOT-180, FR-BOT-190, FR-BOT-200, FR-BOT-210, FR-MAP-150, FR-BOT-220, FR-BOT-060, FR-BOT-140, FR-BOT-330, FR-BOT-410, FR-BOT-420, FR-BOT-425, FR-BOT-130, FR-CMD-030
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
        /// The middle of the part of the arena the squad's commander pointed at
        /// (FR-BOT-116), or nil where no commander has named one. A point and not a
        /// word: which quarter of the arena the word means is decided where the words
        /// are, and the deliberation is given the place itself.
        var orderedPart: SIMD3<Double>?
        /// How far apart the arena's two furthest corners are: what nearness to the
        /// ordered part is measured against, so that the term runs from one at the
        /// place itself to nothing at the other end of the island.
        var arenaSpan: Double = .zero
        /// What the squad's commander told it to worry about (FR-CMD-030), or nil where
        /// no commander has spoken: a bot then ranks threats as it did before there
        /// were commanders.
        var priority: CommanderDecision.Threat?
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
        /// The radius of a bot's body (the tuning's): how near a line of fire a
        /// squadmate stands in it (FR-BOT-410).
        var bodyRadius: Double = .zero
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
        // How much of the bot's own reading of the danger survives an order
        // (FR-BOT-130): all of it where there is no order to contradict, and one minus
        // its discipline where there is. The order's own term is weighted by the
        // discipline itself, below, so a bot of discipline 1.0 does what it was told
        // and one of 0.0 never does.
        let local = situation.orderedZone == nil
            ? Fraction.whole
            : Fraction.whole - bot.weights.discipline

        let nearest = situation.snake
            .map { (point: $0, metres: Perception.metres(bot.position, $0)) }
            .min { $0.metres < $1.metres }
        let health = entry.health > .zero ? bot.health / entry.health : .zero

        // Fire: one action for each firearm the bot carries that has a round left and
        // whose range covers the target (FR-BOT-460) — so which weapon it uses is
        // decided by the score, as everything else about a bot is, and not by a rule
        // about primaries and sidearms (ADR-0086).
        //
        // Each is scored with its own numbers (FR-BOT-450): what is left in that
        // magazine against that magazine's size, and how hard it hits against the
        // hardest-hitting thing the bot has. Firing needs something to shoot at that
        // the bot sees now, a line to it and a round to send; a remembered snake is
        // somewhere to be afraid of, not a target. Of the targets, the nearest part of
        // the snake and each enemy bot in view (FR-BOT-060), the one it is already
        // firing at is kept unless another is worth more by the hysteresis margin
        // (FR-BOT-140).
        for slot in Arms.Slot.allCases {
            let firearm = bot.arms[slot]
            guard firearm.rounds > .zero else { continue }
            let loaded = firearm.numbers.magazine > .zero
                ? Double(firearm.rounds) / Double(firearm.numbers.magazine)
                : .zero
            let strength = bot.arms.strength(of: slot)
            let worth = { (metres: Double) in
                term.attack * nearness(metres, within: entry.detectionRange) * loaded * strength
                    * bot.weights.aggression * bot.weights.courage
            }
            if let target = target(for: bot, in: situation, within: firearm.numbers.range, worth: worth) {
                scored.append((.fire(at: target.target, with: slot), target.utility))
            } else if bot.post != nil, let kept = bot.postTarget,
                      let known = remembered(kept, by: bot, in: situation),
                      Perception.metres(bot.position, known.point) <= firearm.numbers.range,
                      !Perception.sees(aim(at: known.target, from: bot, in: situation) ?? known.point, from: bot,
                                       within: entry.detectionRange, plan: situation.plan,
                                       configuration: situation.configuration) {
                // Behind the cover it fired from beside, out of sight of what it was
                // firing at: it comes out again to fire from where it did, at what it
                // knows of it (FR-BOT-420, ADR-0063). It fires only once it sees it
                // (FR-BOT-060). Where it sees the place and nothing there, what it
                // knows is no target.
                scored.append((.fire(at: known.target, with: slot),
                               worth(Perception.metres(bot.position, known.point))))
            }
        }

        // The grenade is a weapon like the others and is scored like one: one left to
        // throw and a target inside the throw range (FR-BOT-460, FR-BOT-470). What it
        // is worth falls with the pouch rather than with a magazine, since a bot is
        // given one, two or three of them for the whole match.
        //
        // Where it would catch a squadmate it can see, or itself, it is not offered at
        // all (FR-BOT-500): an action the bot must never take is one it never scores.
        let pouch = bot.arms.grenades
        if pouch.left > .zero, pouch.carried > .zero {
            let left = Double(pouch.left) / Double(pouch.carried)
            if let throwing = target(for: bot, in: situation, within: pouch.numbers.throwRange, worth: { metres in
                   term.blast * nearness(metres, within: entry.detectionRange) * left
                       * bot.weights.aggression * bot.weights.courage
               }),
               let where_ = aim(at: throwing.target, from: bot, in: situation),
               clear(for: bot, of: where_, within: pouch.numbers.blastRadius, in: situation) {
                // Worth more the more bodies it would catch, and by the same share the
                // damage grows by (FR-BOT-490), so that one number in the configuration
                // moves both. A grenade on a single enemy is worth less than a shot
                // from a loaded primary; one on a knot of three is worth more.
                let bodies = caught(by: bot, at: where_, within: pouch.numbers.blastRadius, in: situation)
                let more = Fraction.whole + (bodies - Fraction.whole) * pouch.numbers.furtherPartShare
                scored.append((.throwGrenade(at: throwing.target), throwing.utility * more))
            }
        }

        // The knife, while it still has one: at the reach of an arm it is struck with
        // (FR-BOT-510), and a little further off it is thrown and gone (FR-BOT-520).
        // Its own weight is what makes a throw cost something, since what a bot gives
        // up is the only knife it has.
        if let knife = bot.arms.knife {
            if let close = target(for: bot, in: situation, within: knife.numbers.reach, worth: { metres in
                   term.attack * nearness(metres, within: entry.detectionRange)
                       * bot.weights.aggression * bot.weights.courage
               }) {
                scored.append((.strike(at: close.target), close.utility))
            }
            if let away = target(for: bot, in: situation, within: knife.numbers.throwRange, worth: { metres in
                   term.thrown * nearness(metres, within: entry.detectionRange)
                       * bot.weights.aggression * bot.weights.courage
               }) {
                scored.append((.throwKnife(at: away.target), away.utility))
            }
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
                               * bot.weights.panic * local))
        }

        // Flight: the same fear, spent on distance rather than on a wall. A whole bot
        // is afraid too (FR-BOT-210) — the fear of a wound already taken is what a
        // wound adds, not the whole of what there is to be afraid of.
        if let nearest, let away = away(from: nearest.point, for: bot, in: situation) {
            let closeness = nearness(nearest.metres, within: entry.detectionRange)
            let fear = situation.configuration.fearWhenUnhurt + (term.wounded - health)
            scored.append((.flee(to: away), term.threat * closeness * fear * bot.weights.panic * local))
        }

        // An order to obey is the one thing discipline scales; without a commander
        // there is no order, and the action is simply not on the list.
        if let zone = situation.orderedZone {
            // Obeying does not get better or worse with distance in anything the
            // specification says; what varies it is how disciplined the bot is — and,
            // as the danger closes, how brave: holding ground under it is the second
            // term courage pulls on (FR-BOT-090). With nothing near, the order is
            // worth its weight times discipline alone.
            scored.append((.moveToOrderedZone(zone),
                           term.obedience * bot.weights.discipline
                               * holding(against: danger, for: bot, within: entry.detectionRange)))
        }

        // Reload: one action for each firearm that is not full and has a spare magazine
        // left (FR-BOT-540), as firing each is one of its own (FR-BOT-460). A bot with a
        // dry rifle and a full pistol has one reload to score and not two, and which
        // magazine it fills is the score's business rather than a rule's.
        //
        // One per weapon rather than one for everything, because each takes its own
        // time (FR-BOT-550) and a single act cannot take two lengths; ADR-0090
        // supersedes that part of ADR-0086.
        for slot in bot.arms.reloadable {
            // Squared, so that the term stays flat while there is a magazine to
            // spend and climbs only as it runs out: a bot that reloaded after every
            // shot would spend a firefight looking at its hands.
            let spent = bot.arms[slot].spent
            // And less the braver the bot is: stepping out of danger to fill a magazine
            // is the term courage pulls down (FR-BOT-090), which is what makes a brave
            // bot draw what it has and close with the enemy instead (FR-BOT-570).
            let daring = Fraction.whole - bot.weights.courage * Utility.reloadCourageShare
            // And by what the weapon is worth filling, the same share firing it is
            // scored by (FR-BOT-450, ADR-0086): an empty pistol is as empty as an empty
            // rifle and matters half as much, so a bot with both dry fills the rifle.
            scored.append((.reload(slot), term.empty * spent * spent * bot.arms.strength(of: slot) * daring))
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

        // What the squad was told to worry about ranks the kinds of target over all the
        // weapons together and not inside each of them (FR-CMD-030). Told to worry
        // about the snake, a bot does not throw its knife at an enemy because the snake
        // stands a metre beyond the throw: while anything it carries reaches a part of
        // the snake, the enemy is not what this slot is for.
        var ranked = scored
        if let priority = situation.priority {
            let isSnake = { (action: Action) in
                if case .snake = aimed(action) { return true }
                return false
            }
            let wanted: ((Action) -> Bool)?
            switch priority {
            case .snake: wanted = isSnake
            case .enemy: wanted = { aimed($0) != nil && !isSnake($0) }
            case .withdraw: wanted = nil
            }
            if let wanted, ranked.contains(where: { wanted($0.0) }) {
                ranked = ranked.filter { aimed($0.0) == nil || wanted($0.0) }
            }
        }

        // An action whose goal the graph had no route to is left out of this slot and
        // of this slot only (FR-BOT-167): the tail that cut the passage may be gone a
        // second later, so the exclusion is one slot wide and the bot asks again.
        return ranked.map { (action: $0.0, utility: $0.1) }.filter { $0.action != bot.unreachable }
    }

    /// What the bot fires at, and what firing at it is worth: the best of the nearest
    /// part of the snake it sees and each enemy bot it sees with a line of fire to it,
    /// by `worth` of the distance, except that the target it is already firing at is
    /// kept while nothing else is worth more by the hysteresis margin (FR-BOT-140).
    /// Two targets are one where both are the snake, or both the same bot.
    ///
    /// `range` is how far the weapon being scored reaches: a target further off than
    /// that is no target for it at all, rather than one it would score at nothing
    /// (FR-BOT-460).
    static func target(for bot: Bot, in situation: Situation, within range: Double,
                       worth: (Double) -> Double) -> (target: Target, utility: Double)? {
        var candidates: [(target: Target, utility: Double)] = []
        var snakeOverride = false
        let snake = situation.inView
            .map { (point: $0, metres: Perception.metres(bot.position, $0)) }
            .min { $0.metres < $1.metres }
        if let snake, snake.metres <= range, Sight.isClear(from: bot.eye, to: snake.point, through: situation.plan) {
            // Within the override distance the snake is the top threat, whatever else
            // there is and whatever the bot was firing at (FR-BOT-120); beyond it, a calm
            // squad does not hunt it (FR-BOT-180).
            if snake.metres <= situation.configuration.overrideDistance {
                snakeOverride = true
                candidates.append((.snake(at: snake.point), worth(snake.metres)))
            } else if situation.awareness != .calm {
                candidates.append((.snake(at: snake.point), worth(snake.metres)))
            }
        }
        for enemy in situation.enemiesInView {
            let eye = enemy.point + SIMD3(0, bot.eyeHeight, 0)
            guard Perception.metres(bot.position, enemy.point) <= range else { continue }
            guard Sight.isClear(from: bot.eye, to: eye, through: situation.plan) else { continue }
            candidates.append((.bot(id: enemy.id), worth(Perception.metres(bot.position, enemy.point))))
        }
        // Not through a squadmate it sees (FR-BOT-410): a round strikes whoever is in
        // its way (FR-BOT-400).
        let range = situation.configuration.archetypes[bot.archetype.rawValue]?.detectionRange ?? .zero
        let mates = situation.allies.filter { mate in
            mate.id != bot.id && mate.squad == bot.squad && mate.isAlive
                && Perception.sees(mate.eye, from: bot, within: range, plan: situation.plan,
                                   configuration: situation.configuration)
        }
        if !mates.isEmpty {
            candidates = candidates.filter { candidate in
                guard let aim = aim(at: candidate.target, from: bot, in: situation) else { return true }
                return !mates.contains { stands($0, across: bot.eye, to: aim, in: situation) }
            }
        }
        if snakeOverride, let snake = candidates.first(where: { if case .snake = $0.target { true } else { false } }) {
            return snake
        }
        // What the squad was told to worry about ranks the kinds of target rather than
        // scaling them (FR-CMD-030), which is how the one other priority in this
        // function works: the snake within the override distance has just won above,
        // whatever the commander said (FR-BOT-120). Told to worry about the snake, a
        // bot fires at a part of it in view over any enemy; told to worry about the
        // enemy, the other way round. `withdraw` names nothing to fire at, and leaves
        // the ranking where it was.
        //
        // Narrowing the candidates rather than returning one of them keeps the
        // hysteresis below: the margin that stops a bot swapping targets every step
        // (FR-BOT-140) still applies, within the kind the commander named.
        let isSnake = { (candidate: (target: Target, utility: Double)) in
            if case .snake = candidate.target { true } else { false }
        }
        switch situation.priority {
        case .snake where candidates.contains(where: isSnake):
            candidates = candidates.filter(isSnake)
        case .enemy where candidates.contains(where: { !isSnake($0) }):
            candidates = candidates.filter { !isSnake($0) }
        case .snake, .enemy, .withdraw, nil:
            break
        }
        // The first of the best, so that a tie goes the same way every time.
        var best: (target: Target, utility: Double)?
        for candidate in candidates where candidate.utility > (best?.utility ?? -.infinity) { best = candidate }
        guard let best else { return nil }
        guard case .fire(let current, _) = bot.action,
              let kept = candidates.first(where: { same($0.target, current) }),
              best.utility - kept.utility < situation.configuration.hysteresisMargin else { return best }
        return kept
    }

    /// What a bot knows of a target it is not seeing now: the part of the snake nearest
    /// it that it remembers, or where it last saw the enemy bot. Nil where it knows of
    /// none.
    static func remembered(_ target: Target, by bot: Bot,
                           in situation: Situation) -> (target: Target, point: SIMD3<Double>)? {
        switch target {
        case .snake:
            return situation.snake.min { Perception.metres(bot.position, $0) < Perception.metres(bot.position, $1) }
                .map { (target: .snake(at: $0), point: $0) }
        case .bot(let id):
            return bot.knowledge.enemies[id].map { (target: target, point: $0.point) }
        }
    }

    /// Where a round fired at a target is sent (FR-BOT-060): the middle of the snake's
    /// body over the part aimed at, which lies on the ground under it, raised by the
    /// body's radius; an enemy's eyes, where it was seen now, or else where it was last
    /// seen. Nil for an enemy it knows nothing of.
    static func aim(at target: Target, from bot: Bot, in situation: Situation) -> SIMD3<Double>? {
        switch target {
        case .snake(let point):
            return point + SIMD3(.zero, situation.bodyRadius, .zero)
        case .bot(let id):
            let point = situation.enemiesInView.first { $0.id == id }?.point ?? bot.knowledge.enemies[id]?.point
            return point.map { $0 + SIMD3(.zero, bot.eyeHeight, .zero) }
        }
    }

    /// Whether a bot stands in the way of a line: its body — the figure's height and
    /// the body radius round the ground it stands on — comes within reach of the line
    /// (FR-BOT-410), as a round's would strike it (FR-BOT-400).
    static func stands(_ mate: Bot, across from: SIMD3<Double>, to aim: SIMD3<Double>,
                       in situation: Situation) -> Bool {
        let radius = situation.bodyRadius
        let top = max(radius, situation.configuration.figureHeight - radius)
        return Flight.contact(from: from, to: aim, axis: mate.position + SIMD3(.zero, radius, .zero),
                              mate.position + SIMD3(.zero, top, .zero), radius: radius) != nil
    }

    /// What an action is aimed at, where it is aimed at anything: every weapon has a
    /// target and nothing else does.
    static func aimed(_ action: Action) -> Target? {
        switch action {
        case .fire(let target, _), .throwGrenade(let target),
             .strike(let target), .throwKnife(let target): return target
        case .takeCover, .moveToOrderedZone, .flee, .reload, .heal, .advance, .explore: return nil
        }
    }

    /// How many bodies of the other side a blast at `point` would catch, as the bot
    /// sees it: each enemy bot in view standing within the radius, and the snake
    /// counted once however much of it lies there.
    ///
    /// The damage does grow with every part of the snake covered (FR-BOT-490); what a
    /// bot weighs is bodies, because a snake lying along a blast would otherwise be
    /// worth ten of anything and a bot would stand in front of it throwing.
    static func caught(by bot: Bot, at point: SIMD3<Double>, within radius: Double,
                       in situation: Situation) -> Double {
        var bodies = situation.enemiesInView.filter { Perception.metres($0.point, point) <= radius }.count
        if situation.inView.contains(where: { Perception.metres($0, point) <= radius }) { bodies += 1 }
        return Double(max(bodies, 1))
    }

    /// Whether a bot may throw at a point: nobody of its own within the blast —
    /// neither a squadmate it can see (FR-BOT-500) nor itself.
    ///
    /// A squadmate it cannot see is one it cannot know to be there, which is what
    /// FR-BOT-220 obliges and what makes the occasional throw onto one's own squad
    /// correct rather than a fault. The thrower's own place is refused here rather
    /// than left to its score, as ADR-0075 expected: the blast takes the thrower
    /// (FR-BOT-480) and no term in this file yet prices what a bot does to itself.
    static func clear(for bot: Bot, of point: SIMD3<Double>, within radius: Double,
                      in situation: Situation) -> Bool {
        guard Perception.metres(bot.position, point) > radius else { return false }
        let range = situation.configuration.archetypes[bot.archetype.rawValue]?.detectionRange ?? .zero
        return !situation.allies.contains { mate in
            mate.id != bot.id && mate.squad == bot.squad && mate.isAlive
                && Perception.metres(mate.position, point) <= radius
                && Perception.sees(mate.eye, from: bot, within: range, plan: situation.plan,
                                   configuration: situation.configuration)
        }
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
        // The cell nearest what it believes is found over the whole graph and can lie
        // the other side of a wall (ADR-0059); the one it has not seen is walked to and
        // cannot. So an advance is the motive this exclusion is usually about, and it is
        // asked here rather than in `scores`, which never offers either (FR-BOT-167).
        var advance = situation.enemyBelief
            .flatMap { nearestCell(to: $0, from: here, for: bot, in: situation) }
            .map { Action.advance(to: $0) }
        var explore = unseen(from: here, for: bot, in: situation).map { Action.explore(to: $0) }
        if advance == bot.unreachable { advance = nil }
        if explore == bot.unreachable { explore = nil }
        let aggression = bot.weights.aggression
        switch (advance, explore) {
        case (let target?, let look?):
            return aggression >= Fraction.whole - aggression ? target : look
        case (let target?, nil): return target
        case (nil, let look?): return look
        case (nil, nil): return nil
        }
    }

    /// The nearest cell, along the walk from where the bot stands and other than the
    /// one it stands in, that it does not know (FR-BOT-370), on any floor the graph
    /// joins.
    static func unseen(from here: NavigationGraph.Node, for bot: Bot,
                       in situation: Situation) -> NavigationGraph.Node? {
        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        let held = taken(by: bot, in: situation)
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            if node != here, !situation.knows(node), !held.contains(node) { return node }
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
    static func nearestCell(to point: SIMD3<Double>, from here: NavigationGraph.Node, for bot: Bot,
                            in situation: Situation) -> NavigationGraph.Node? {
        var best: (node: NavigationGraph.Node, metres: Double)?
        let held = taken(by: bot, in: situation)
        for node in situation.graph.nodes where node != here && !held.contains(node) {
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
    /// far as a path can count — by lying near the part of the arena the squad's
    /// commander pointed at (FR-BOT-116), and, while the bot's squad is alarmed, by lying
    /// within the grouping distance of a squadmate (FR-BOT-190). One where the bot knows
    /// no snake, stands under no order and its squad is not alarmed.
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
        // Where the commander pointed (FR-BOT-116): a whole at the place itself, nothing
        // at the far end of the arena, and the slope between is what makes every step
        // towards it worth more than a step away. Measured against the arena's own span
        // so that the same order means the same thing on any map.
        let ordered: Double
        if let part = situation.orderedPart, situation.arenaSpan > .zero {
            ordered = term.ordered * nearness(Perception.metres(centre(of: node, in: situation), part),
                                              within: situation.arenaSpan)
        } else {
            ordered = .zero
        }
        guard let head = situation.snakeHead,
              let range = situation.configuration.archetypes[bot.archetype.rawValue]?.detectionRange,
              range > .zero else { return Fraction.whole + together + ordered }
        let floor = situation.plan.floorHeight
        let above = floor > .zero ? (centre(of: node, in: situation).y - head.y) / floor : .zero
        let path = situation.fromHead[node].map {
            Double($0) / Double(MapGrid.stepsPerNeighbour) * situation.cellSize / range
        } ?? Fraction.whole
        return Fraction.whole + term.height * clamped(above) + term.snakePath * clamped(path)
            + together + ordered
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
    /// Nil where the bot is already hidden in the cell it stands in: it is in cover and
    /// has no cover to take (FR-BOT-119). Trading a wall that holds for another wall is
    /// the standing still concept §9.2 calls the signature stupidity, and a bot that
    /// scores it instead of nothing never gets as far as anything else (ADR-0081).
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
        // Whether what this search hides from can see into a cell: a part of the snake
        // with a line to its ground, or an enemy whose eyes have a line to where the
        // bot's eyes would be, standing in it (FR-BOT-330, ADR-0022). The bot's own cell
        // and every candidate are asked in the same words, so the two cannot drift apart.
        func watched(_ node: NavigationGraph.Node) -> Bool {
            let there = centre(of: node, in: situation)
            return byNearness.contains { Sight.isClear(from: $0, to: there, through: situation.plan) }
                || shooters.contains { Sight.isClear(from: $0, to: there + rise, through: situation.plan) }
        }
        // Already in cover: nothing to do about cover (FR-BOT-119).
        guard watched(here) else { return nil }

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
        for cell in ranked where !watched(cell.node) {
            return (node: cell.node, metres: cell.metres)
        }
        return nil
    }

    /// Where a bot fires from beside cover (FR-BOT-420): of the cells it knows within
    /// the cover search distance, nearest first, the first from which its eyes have a
    /// line of fire to `aim` and which has a cell next to it that no enemy and no part
    /// of the snake it knows of watches; with that cell, where it steps back to
    /// (FR-BOT-425). Neither is a cell another bot holds or is making for
    /// (FR-BOT-530). Nil where there is none.
    ///
    /// Whether a cell is watched is asked once whatever number of cells it lies next
    /// to, and only of a cell next to one with a line of fire (NFR-PERF-020).
    static func post(for bot: Bot, aim: SIMD3<Double>,
                     in situation: Situation) -> (post: NavigationGraph.Node, refuge: NavigationGraph.Node)? {
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }
        let rise = SIMD3(.zero, bot.eyeHeight, .zero)
        var watched: [NavigationGraph.Node: Bool] = [:]
        // A cell another bot holds or is making for is not one of these, and the walk
        // has already left it out (FR-BOT-530); the refuge beside the post is chosen
        // off the graph rather than off the walk, so it is asked here.
        let held = taken(by: bot, in: situation)
        let cells = walk(from: here, within: coverSearch(situation.configuration), for: bot, in: situation)
            .filter { situation.knows($0.node) }
            .enumerated()
            .sorted { $0.element.metres != $1.element.metres ? $0.element.metres < $1.element.metres : $0.offset < $1.offset }
            .map(\.element.node)
        for cell in cells {
            guard Sight.isClear(from: centre(of: cell, in: situation) + rise, to: aim, through: situation.plan)
            else { continue }
            for next in situation.graph.neighbours(of: cell).sorted(by: order)
            where situation.knows(next) && !held.contains(next) {
                if watched[next] == nil { watched[next] = isWatched(next, for: bot, in: situation) }
                if watched[next] == false { return (post: cell, refuge: next) }
            }
        }
        return nil
    }

    /// Whether a bot standing in a cell is watched by what it knows of: a part of the
    /// snake with a line to the cell's ground, or an enemy whose eyes, where it was last
    /// seen, have a line to where the bot's eyes would be (FR-BOT-330).
    static func isWatched(_ node: NavigationGraph.Node, for bot: Bot, in situation: Situation) -> Bool {
        let rise = SIMD3(.zero, bot.eyeHeight, .zero)
        let there = centre(of: node, in: situation)
        return situation.enemies.contains { Sight.isClear(from: $0 + rise, to: there + rise, through: situation.plan) }
            || situation.snake.contains { Sight.isClear(from: $0, to: there, through: situation.plan) }
    }

    /// The cells a bot may not set out for: the cells the bots it sees stand in, and
    /// the cells its own squad is already making for (FR-BOT-530).
    ///
    /// Two sets, because a bot acts on what it knows (FR-BOT-220): where a bot stands
    /// can be seen, so an enemy in view holds its cell as much as a squadmate does,
    /// while where a bot is going is told to its own squad and to nobody else. An
    /// enemy it remembers and does not see holds nothing — the memory is of a place it
    /// was. A body holds nothing either: only the living are pushed apart (FR-BOT-320).
    ///
    /// Where its own squad is going is read off each squadmate's last decision
    /// (`Execution.destination(of:)`), which is the one answer to that question in the
    /// game, together with the cell it fires from and the cell it reloads in — a bot
    /// holding a post holds the pair (FR-BOT-420, FR-BOT-425).
    ///
    /// The cell the bot itself stands in is not in the set: it is not somewhere it is
    /// going, and what being there means is FR-BOT-119's.
    static func taken(by bot: Bot, in situation: Situation) -> Set<NavigationGraph.Node> {
        var cells: Set<NavigationGraph.Node> = []
        for mate in situation.allies where mate.id != bot.id && mate.squad == bot.squad && mate.isAlive {
            cells.insert(NavigationGraph.Node(floor: mate.floor,
                                              x: Int((mate.position.x / situation.cellSize).rounded()),
                                              z: Int((mate.position.z / situation.cellSize).rounded())))
            for node in [Execution.destination(of: mate), mate.post, mate.refuge] {
                if let node { cells.insert(node) }
            }
        }
        for enemy in situation.enemiesInView {
            if let node = cell(of: enemy.point, graph: situation.graph, cellSize: situation.cellSize,
                               floorHeight: situation.plan.floorHeight) {
                cells.insert(node)
            }
        }
        return cells
    }

    /// The cells a bot can walk to without leaving the search distance, on any floor
    /// the graph joins (FR-BOT-110), nearest along the walk first, each with how far
    /// it is from the bot across the room.
    ///
    /// Walked outwards over the graph rather than scanned over the map, so that every
    /// cell given is one the bot can get to (FR-BOT-118); out of reach is also as far
    /// as the walk goes, since what lies beyond is only approached through cells the
    /// bot would have to cross to get there.
    ///
    /// A cell another bot holds or is making for is not given (FR-BOT-530), which is
    /// what takes it out of every search that chooses a cell to move to — cover, the
    /// post beside it, the order's place and flight all choose from this walk. The
    /// walk still goes through such a cell: another bot standing in it is not a wall,
    /// and a route that crosses it is as good as any (FR-BOT-300).
    static func walk(from here: NavigationGraph.Node, within reach: Double, for bot: Bot,
                     in situation: Situation) -> [(node: NavigationGraph.Node, metres: Double)] {
        var cells: [(node: NavigationGraph.Node, metres: Double)] = []
        var seen: Set<NavigationGraph.Node> = [here]
        var queue = [here]
        var index = queue.startIndex
        let held = taken(by: bot, in: situation)
        while index < queue.endIndex {
            let node = queue[index]
            queue.formIndex(after: &index)
            let metres = Perception.metres(bot.position, centre(of: node, in: situation))
            guard metres <= reach else { continue }
            if !held.contains(node) { cells.append((node: node, metres: metres)) }
            for next in situation.graph.neighbours(of: node).sorted(by: order) where seen.insert(next).inserted {
                queue.append(next)
            }
        }
        return cells
    }

    /// Where an order sends a bot (FR-BOT-116): of the cells it knows within the cover
    /// search distance and other than the one it stands in, the one worth the most.
    ///
    /// Nil where no order names a place, and nil where nothing within reach is worth
    /// more than where the bot already stands — which is the same shape cover has since
    /// FR-BOT-119: an action with nothing to gain is not on the list rather than on it
    /// at nothing.
    ///
    /// The cell is the bot's own best and not a cell the order named: a commander says
    /// which part of the arena matters, and which cell of it a bot takes is the bot's
    /// business — its cover, its height, its squadmates, all of them already in `worth`
    /// (ADR-0085).
    static func ordered(for bot: Bot, in situation: Situation) -> NavigationGraph.Node? {
        guard situation.orderedPart != nil else { return nil }
        let here = NavigationGraph.Node(floor: bot.floor,
                                        x: Int((bot.position.x / situation.cellSize).rounded()),
                                        z: Int((bot.position.z / situation.cellSize).rounded()))
        guard situation.graph.isWalkable(here) else { return nil }
        var best: (node: NavigationGraph.Node, value: Double)?
        let standing = worth(of: here, for: bot, in: situation)
        for cell in walk(from: here, within: coverSearch(situation.configuration), for: bot, in: situation)
        where cell.node != here && situation.knows(cell.node) {
            let value = worth(of: cell.node, for: bot, in: situation)
            if value > (best?.value ?? standing) { best = (cell.node, value) }
        }
        return best?.node
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
                     in situation: Situation, within asked: Double? = nil) -> NavigationGraph.Node? {
        // As far as cover is looked for, unless somebody asks for further: a withdrawal
        // ordered by a commander is given the order's own reach (FR-CMD-040, ADR-0084),
        // and flight from the snake is not (FR-BOT-118).
        let reach = asked ?? coverSearch(situation.configuration)
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

    /// How much of its ground a bot holds under the danger it knows of: a whole with
    /// nothing near, its courage with the danger at hand, and between the two as the
    /// danger closes (FR-BOT-090). A fearless bot holds whatever comes; one with no
    /// courage at all abandons the position the moment something reaches it.
    private static func holding(against danger: Double?, for bot: Bot, within limit: Double) -> Double {
        guard let danger else { return Fraction.whole }
        let closeness = nearness(danger, within: limit)
        return Fraction.whole - closeness * (Fraction.whole - bot.weights.courage)
    }

    /// One at arm's length, nothing at the edge of the world.
    private static func nearness(_ metres: Double, within limit: Double) -> Double {
        guard limit > .zero else { return .zero }
        return max(.zero, Fraction.whole - metres / limit)
    }
}
