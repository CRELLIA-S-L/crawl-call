// A round in flight (FR-BOT-060). A bot fires at the point where its target is as it
// fires, and the round takes time to get there: a target that has moved on by then
// is missed, and the round goes on to whatever is in its way (FR-BOT-400, FR-BOT-405).
//
// implements: FR-BOT-060, FR-VIEW-170, FR-BOT-400
import Foundation

struct Round: Equatable {
    /// Who fired it: the one bot it never strikes (FR-BOT-400).
    let shooter: Int
    /// Whose round it is, so that it can be drawn in that squad's colour (FR-VIEW-060).
    let squad: Squad
    /// Where it is now: where it left from, the shooter's eyes (ADR-0022), until it moves.
    var position: SIMD3<Double>
    /// Where it left from, and the point it was sent at: where its target was as it
    /// was fired (FR-BOT-060).
    let from: SIMD3<Double>
    let towards: SIMD3<Double>
    /// Which way it flies, of length one.
    let direction: SIMD3<Double>
    /// What it deals to what it strikes: the damage per shot of the shooter's weapon.
    let damage: Double
    /// Metres it has flown.
    var flown: Double = .zero

    /// A round from `from` towards `towards`; nil where the two are one point and it has
    /// no way to fly.
    init?(shooter: Int, squad: Squad, from: SIMD3<Double>, towards: SIMD3<Double>, damage: Double) {
        let way = towards - from
        let length = (way * way).sum().squareRoot()
        guard length > Flying.noWay else { return nil }
        self.shooter = shooter
        self.squad = squad
        self.position = from
        self.from = from
        self.towards = towards
        self.direction = way / length
        self.damage = damage
    }
}
