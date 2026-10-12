// A squad as its own commander sees it: the one place the game's numbers become the
// words of IF-CMD-010, and the only place they do.
//
// Everything is read from the role-holder's knowledge and never from the arena. That
// is the literal reading of "from its own point of view": the commander is told what
// its squad has seen and been told (FR-BOT-310), and a commander that knew where the
// snake truly was would be a bot acting on the truth, which FR-BOT-220 forbids the
// bots themselves.
//
// file implements: IF-CMD-010, FR-CMD-020, FR-CMD-070
import Foundation

enum SquadView {
    /// The six figures, by archetype. The names are the bench's, unchanged: they are
    /// part of the configuration a prompt measurement covers (ADR-0017), and inventing
    /// a seventh name would void the reading that says this vocabulary is never
    /// blocked. Both squads use the same six, which never collide because no commander
    /// is told the other crew's names.
    static let names: [Archetype: String] = [
        .assault: "Davis", .heavy: "Pike", .sapper: "Marsh",
        .scout: "Otto", .sniper: "Beans", .medic: "Kit",
    ]

    static func name(of archetype: Archetype) -> String { names[archetype] ?? archetype.rawValue }

    /// What is left of a soldier, in the words the guardrail passes. Three bands and
    /// not a number: a commander deciding whether to pull somebody out needs to know
    /// which of three states they are in, and `health 37` costs tokens to say the same
    /// thing less safely.
    static func standing(of bot: Bot, whole: Double) -> String {
        guard whole > .zero else { return "up" }
        let left = bot.health / whole
        if left > twoThirds { return "up" }
        if left > aThird { return "up but wobbly" }
        return "flat on his back"
    }

    /// What is left in a pouch, or nil where there is nothing worth the tokens: a
    /// soldier with half his rounds is a soldier the commander need hear nothing about.
    /// What it has left is counted over both its firearms (FR-BOT-440): a soldier
    /// with an empty rifle and a full pistol has something to fire with, and the
    /// commander is told about a pouch and not about a weapon.
    static func pouch(of bot: Bot) -> String? {
        let whole = bot.arms.magazines
        guard whole > .zero else { return nil }
        let left = Double(bot.arms.rounds) / Double(whole)
        if left > half { return nil }
        return bot.arms.rounds > .zero ? "running low" : "pouch empty"
    }

    /// Where something stands, in the arena's own quarters. The compass is this file's
    /// and is arbitrary in the way a compass is: -z north, +z south, +x east, -x west,
    /// with the middle its own answer. Coarse on purpose — a model given metres spends
    /// tokens on them and decides no better for it, and the bench's measured states say
    /// "west side" and "north" (ADR-0077).
    static func place(of point: SIMD3<Double>, floor: Int, in bounds: ScenePlan.Bounds) -> String {
        let span = bounds.highest - bounds.lowest
        let middle = (bounds.highest + bounds.lowest) * Geometry.half
        var side = ""
        let fromMiddle = point - middle
        let quarter = SIMD3<Double>(span.x * aQuarter, span.y * aQuarter, span.z * aQuarter)
        let eastWest = abs(fromMiddle.x) > quarter.x ? (fromMiddle.x > .zero ? "east" : "west") : ""
        let northSouth = abs(fromMiddle.z) > quarter.z ? (fromMiddle.z > .zero ? "south" : "north") : ""
        switch (northSouth.isEmpty, eastWest.isEmpty) {
        case (true, true): side = "middle"
        case (true, false): side = eastWest + " side"
        case (false, true): side = northSouth + " side"
        case (false, false): side = northSouth + "-" + eastWest
        }
        return floor > .zero ? side + ", upstairs" : side
    }

    /// The squad's own, as its commander knows them: those still up, and those gone.
    static func crew(of squad: Squad, among bots: [Bot], in bounds: ScenePlan.Bounds,
                     configuration: BotConfiguration) -> (crew: [CommanderInput.Soldier], gone: [String]) {
        var crew: [CommanderInput.Soldier] = []
        var gone: [String] = []
        for bot in bots where bot.squad == squad {
            let name = name(of: bot.archetype)
            guard bot.isAlive else { gone.append(name); continue }
            let entry = configuration.archetypes[bot.archetype.rawValue]
            crew.append(CommanderInput.Soldier(
                name: name,
                standing: standing(of: bot, whole: entry?.health ?? .zero),
                pouch: pouch(of: bot),
                place: place(of: bot.position, floor: bot.floor, in: bounds)))
        }
        return (crew, gone)
    }

    /// The other crew, counted and placed from what this one has seen (FR-BOT-240) —
    /// never from where it truly is.
    static func rivals(known: Knowledge, in bounds: ScenePlan.Bounds) -> String {
        let seen = known.enemyPoints
        guard !seen.isEmpty else { return "not seen" }
        var places: [String] = []
        for point in seen {
            let where_ = place(of: point, floor: .zero, in: bounds)
            if !places.contains(where_) { places.append(where_) }
        }
        return "\(seen.count) seen, \(CommanderInput.list(places))"
    }

    /// Where the squad last saw the snake. `not seen` where it has not, and `not seen`
    /// whatever it knows while the squad is calm, which is FR-CMD-070.
    static func snake(known: Knowledge, awareness: Awareness, from eye: SIMD3<Double>,
                      in bounds: ScenePlan.Bounds) -> String {
        guard awareness != .calm else { return "not seen" }
        let parts = known.snakePoints
        guard let nearest = parts.min(by: { Perception.metres(eye, $0) < Perception.metres(eye, $1) })
        else { return "not seen" }
        let metres = Int(Perception.metres(eye, nearest).rounded())
        return "\(metres) metres away, \(place(of: nearest, floor: .zero, in: bounds))"
    }

    /// The awareness scale in the words a commander hears it in (FR-SCORE-130).
    static func awareness(_ level: Awareness, gone: [String]) -> String {
        switch level {
        case .calm: return "calm"
        case .alarm:
            guard !gone.isEmpty else { return "something is not right" }
            return gone.count == 1
                ? "\(gone[0]) vanished with no trace"
                : "\(gone.count) of ours vanished with no trace"
        case .confirmed: return "there is a snake and it takes people"
        }
    }

    /// The whole of what one squad's commander is told (IF-CMD-010), or nil where
    /// there is nobody to tell: a squad whose role-holder is gone is not called at all
    /// (FR-CMD-020, FR-CMD-120).
    ///
    /// The knowledge read is the role-holder's own, which is the literal reading of
    /// "from its own point of view": it has been told what its squad saw (FR-BOT-310),
    /// and nothing here reaches past it into the arena.
    static func state(of squad: Squad, among bots: [Bot], awareness: Awareness,
                      in bounds: ScenePlan.Bounds, configuration: BotConfiguration,
                      lastCall: CommanderDecision?, truce: String?,
                      events: [String]) -> CommanderInput? {
        guard let holder = bots.first(where: { $0.squad == squad && $0.isCommander && $0.isAlive })
        else { return nil }
        let own = crew(of: squad, among: bots, in: bounds, configuration: configuration)
        return CommanderInput(
            crew: own.crew,
            gone: own.gone,
            rivals: rivals(known: holder.knowledge, in: bounds),
            snake: snake(known: holder.knowledge, awareness: awareness, from: holder.eye, in: bounds),
            awareness: self.awareness(awareness, gone: own.gone),
            lastCall: lastCall?.order.rawValue ?? "none",
            truce: truce,
            events: events)
    }

    private static let twoThirds = 2.0 / 3
    private static let aThird = 1.0 / 3
    private static let half = 0.5
    private static let aQuarter = 0.25
}
