// What a bot carries, and what is left of it (FR-BOT-440).
//
// The numbers of each weapon are the catalogue's and not the bot's (FR-BOT-450): a
// sidearm weaker and shorter-ranged than the primary beside it cannot be described by
// numbers belonging to the body holding both. What a bot owns is which weapons it was
// given and how much of each it has spent.
//
// What a weapon's use costs in time is the weapon's too (FR-BOT-610): each use keeps
// the second it was last taken at, so that a bot firing does not push its knife's next
// strike away. What one act a slot holds the bot to is the bot's and stays there
// (FR-BOT-170).
//
// A bot is armed once, when it is spawned, out of the catalogue the configuration
// carries; a weapon its archetype names and the catalogue does not know is a
// configuration error there and then, the same as an archetype with no entry at all.
//
// file implements: FR-BOT-540, FR-BOT-550, FR-BOT-560, FR-BOT-600, FR-BOT-610, FR-BOT-080, FR-BOT-440, FR-BOT-450, FR-BOT-470, FR-BOT-510, FR-BOT-520
import Foundation

struct Arms: Equatable {
    /// The two firearms a bot carries: the better weapon and the one it falls back on
    /// (INV-BOT-040). `allCases` is the order the deliberation scores them in, so the
    /// primary is the first of two equal scores and a match runs the same way twice.
    enum Slot: CaseIterable, Hashable { case primary, sidearm }

    /// One firearm as a bot carries it: the name the catalogue knows it by, its
    /// numbers, what is left in the magazine, and how many spare magazines are left
    /// for it (FR-BOT-560).
    struct Firearm: Equatable {
        let name: String
        let numbers: BotConfiguration.Firearm
        var rounds: Int
        var spares: Int
        /// Whether filling this magazine is something the bot can do: there is room in
        /// it and a spare to fill it from (FR-BOT-540).
        var isReloadable: Bool { rounds < numbers.magazine && spares > .zero }
        /// How much of the magazine has been fired, as a share (FR-BOT-540).
        var spent: Double {
            guard numbers.magazine > .zero else { return .zero }
            return Fraction.whole - Double(rounds) / Double(numbers.magazine)
        }
    }

    /// The grenades it set out with, and how many it still has (FR-BOT-440).
    struct Grenades: Equatable {
        let name: String
        let numbers: BotConfiguration.Grenade
        /// How many it was given, which is what the share still in its pouch is
        /// measured against, and how many are left.
        let carried: Int
        var left: Int
    }

    /// Its knife. One and not a number of them, because a thrown knife is gone
    /// (FR-BOT-520).
    struct Knife: Equatable {
        let name: String
        let numbers: BotConfiguration.Knife
    }

    /// One use of one weapon: which weapon it is, and which way it is used
    /// (FR-BOT-610). A closed set, because a kind of weapon is a table in the
    /// catalogue and a type beside it (IF-BOT-010) and never something a match
    /// discovers — which is why this is an enumeration and not a protocol the
    /// weapons conform to: a bot is a value compared whole, and the match must run
    /// the same way twice (ADR-0093).
    enum Use: Hashable {
        case shot(Slot)
        case throwGrenade
        case strike
        case throwKnife
    }

    /// Every use there is, in the order the deliberation scores them in: the firearms
    /// first, by slot, as `Slot.allCases` has it, then the pouch and the knife.
    static let uses: [Use] = Slot.allCases.map(Use.shot) + [.throwGrenade, .strike, .throwKnife]

    /// One of the things a bot carries: what a use is a use of, and what keeps the
    /// clock (FR-BOT-610). The knife struck with and the knife thrown are one weapon
    /// and wait on one time — which is what keeps a bot that has just struck from
    /// throwing away the knife it is about to strike with again.
    enum Piece: Hashable {
        case firearm(Slot)
        case pouch
        case knife
    }

    /// Which weapon a use is a use of.
    static func piece(of use: Use) -> Piece {
        switch use {
        case .shot(let slot): return .firearm(slot)
        case .throwGrenade: return .pouch
        case .strike, .throwKnife: return .knife
        }
    }

    var primary: Firearm
    var sidearm: Firearm
    var grenades: Grenades
    /// Nil once the knife has been thrown (FR-BOT-520).
    var knife: Knife?
    /// When each weapon was last used, in seconds of the match (FR-BOT-610). A weapon
    /// with no entry here has never been used and nothing holds it back.
    ///
    /// The clock is the weapon's and not the bot's: a bot that fired would otherwise
    /// push its knife's next strike away, and at a knife worth twenty damage every
    /// five seconds that is the difference between a weapon and none.
    var lastUsed: [Piece: Double] = [:]

    /// The arms an archetype names, taken out of the catalogue. Nil where it names a
    /// weapon the catalogue does not hold.
    init?(_ arms: BotConfiguration.Arms, from weapons: BotConfiguration.Weapons) {
        guard let primary = weapons.firearms[arms.primary],
              let sidearm = weapons.firearms[arms.sidearm],
              let grenade = weapons.grenades[arms.grenade],
              let knife = weapons.knives[arms.knife] else { return nil }
        self.primary = Firearm(name: arms.primary, numbers: primary, rounds: primary.magazine,
                               spares: primary.spareMagazines)
        self.sidearm = Firearm(name: arms.sidearm, numbers: sidearm, rounds: sidearm.magazine,
                               spares: sidearm.spareMagazines)
        self.grenades = Grenades(name: arms.grenade, numbers: grenade,
                                 carried: arms.grenadesCarried, left: arms.grenadesCarried)
        self.knife = Knife(name: arms.knife, numbers: knife)
    }

    subscript(slot: Slot) -> Firearm {
        get { slot == .primary ? primary : sidearm }
        set { if slot == .primary { primary = newValue } else { sidearm = newValue } }
    }

    /// Rounds in everything it carries, and the rounds everything holds when full:
    /// what a bot has left to fire and what reloading gives it back. A bot with two
    /// firearms has run dry when both have.
    var rounds: Int { Slot.allCases.reduce(.zero) { $0 + self[$1].rounds } }
    var magazines: Int { Slot.allCases.reduce(.zero) { $0 + self[$1].numbers.magazine } }

    /// How one firearm stands against the best the bot carries, in damage: a whole for
    /// the harder-hitting weapon and a share for the other. It is what makes the
    /// sidearm the weapon a bot falls back on rather than one it picks first — with a
    /// full magazine in each, the primary scores the higher by exactly this (ADR-0086),
    /// and INV-BOT-040 is what guarantees the whole falls to the primary.
    func strength(of slot: Slot) -> Double {
        let best = Slot.allCases.map { self[$0].numbers.damage }.max() ?? .zero
        guard best > .zero else { return .zero }
        return self[slot].numbers.damage / best
    }

    /// The knife gone, thrown and not picked up again (FR-BOT-520).
    mutating func throwKnife() { knife = nil }

    /// How long after one use of a weapon the same weapon may be used again, out of
    /// the catalogue (FR-BOT-450, FR-BOT-610).
    ///
    /// Nothing for the pouch: the catalogue gives the grenade no time between throws,
    /// and what limits it is how many a bot carries. So a throw is as quick as the
    /// slot that chose it, which is what the maintainer asked of it on 2026-10-13, and
    /// a bot that has just struck waits for the knife either way it means to use it.
    func between(_ piece: Piece) -> Double {
        switch piece {
        case .firearm(let slot): return self[slot].numbers.timeBetweenShots
        case .knife: return knife?.numbers.timeBetweenStrikes ?? .zero
        case .pouch: return .zero
        }
    }

    /// How many times a use is left to the bot: the rounds in that magazine, the
    /// grenades in the pouch, and the knife while it is still there (FR-BOT-440).
    func left(of use: Use) -> Int {
        switch use {
        case .shot(let slot): return self[slot].rounds
        case .throwGrenade: return grenades.left
        case .strike, .throwKnife: return knife == nil ? .zero : Firing.oneWeapon
        }
    }

    /// Whether a use may be taken at `now`: something is left of it, and its own time
    /// has passed since it was last taken (FR-BOT-600, FR-BOT-610).
    ///
    /// One predicate for both halves of a bot's frame — what the deliberation offers
    /// and what the execution carries out — so that an action which cannot be taken
    /// is not scored rather than scored, chosen and then refused (ADR-0093).
    func ready(_ use: Use, at now: Double) -> Bool {
        guard left(of: use) > .zero else { return false }
        let piece = Arms.piece(of: use)
        guard let last = lastUsed[piece] else { return true }
        return now - last >= between(piece) - Firing.cadenceSlack
    }

    /// One use taken: what it spends is spent, and its own clock is set to `now`
    /// (FR-BOT-450, FR-BOT-520, FR-BOT-610). A strike spends nothing — only a throw
    /// costs a bot its knife (FR-BOT-520).
    mutating func spend(_ use: Use, at now: Double) {
        switch use {
        case .shot(let slot):
            self[slot].rounds = max(.zero, self[slot].rounds - Firing.roundsPerShot)
        case .throwGrenade:
            grenades.left = max(.zero, grenades.left - Firing.oneWeapon)
        case .throwKnife:
            throwKnife()
        case .strike:
            break
        }
        lastUsed[Arms.piece(of: use)] = now
    }

    /// One magazine full again, at the cost of one of the spares carried for it
    /// (FR-BOT-550, FR-BOT-560). A firearm with no spare left stays as it is, which is
    /// also why it is never offered as an action (FR-BOT-540).
    ///
    /// One weapon and not both: each takes its own time (FR-BOT-550), and a single act
    /// cannot take two lengths — which is what ADR-0086's one reload for everything
    /// was, and ADR-0090 supersedes.
    mutating func fill(_ slot: Slot) {
        guard self[slot].spares > .zero else { return }
        self[slot].spares -= 1
        self[slot].rounds = self[slot].numbers.magazine
    }

    /// Which firearms could be filled now: each is an action of its own (FR-BOT-540).
    var reloadable: [Slot] { Slot.allCases.filter { self[$0].isReloadable } }
}
