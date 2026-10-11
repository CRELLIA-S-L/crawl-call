// What each squad knows of the snake, as one state that only rises (FR-SCORE-130), and
// what raises it: a meal seen, reported after a delay by a witness still there to report
// it (FR-SCORE-070, FR-SCORE-080, FR-SCORE-090, FR-SCORE-100), and a squadmate's body
// gone from where it fell (FR-SCORE-125).
//
// A body that shows the snake killed it (FR-SCORE-110, FR-SCORE-120) has no case yet:
// the snake kills nobody it does not eat.
//
// file implements: FR-SCORE-130, FR-SCORE-070, FR-SCORE-080, FR-SCORE-090, FR-SCORE-100, FR-SCORE-125
import Foundation

/// A squad's state about the snake (FR-SCORE-130): everything explained, people
/// vanishing without trace, or the snake known.
enum Awareness: Int, Comparable {
    case calm
    case alarm
    case confirmed

    static func < (a: Awareness, b: Awareness) -> Bool { a.rawValue < b.rawValue }
}

struct Stealth: Equatable {
    /// One meal: whom, where it could be seen, and when it began and ended — begun at
    /// the coil round a living bot, since that is where it is seen to begin
    /// (FR-SNAKE-280), and nil at its end while it is under way.
    struct Meal: Equatable {
        let prey: Int
        let point: SIMD3<Double>
        var ended: Double?
        /// Who has already been recorded as its witness.
        var witnesses: Set<Int> = []
    }

    /// A witness's report on its way to its squad (FR-SCORE-090).
    struct Report: Equatable {
        let witness: Int
        let squad: Squad
        let due: Double
    }

    /// A squadmate that fell or vanished, where its squad last knew it to be
    /// (FR-SCORE-125).
    struct Loss: Equatable {
        let squad: Squad
        let point: SIMD3<Double>
    }

    /// Every squad starts calm (FR-SCORE-130).
    private(set) var awareness: [Squad: Awareness] = Dictionary(uniqueKeysWithValues: Squad.allCases.map { ($0, .calm) })
    /// The meal under way, and those ended recently enough to still be witnessed.
    private(set) var meals: [Meal] = []
    private(set) var reports: [Report] = []
    /// By the lost bot's id.
    private(set) var losses: [Int: Loss] = [:]

    /// A squad's state, calm where it has none.
    func of(_ squad: Squad) -> Awareness { awareness[squad] ?? .calm }

    /// Raises a squad's state, never lowers it (FR-SCORE-130).
    mutating func raise(_ squad: Squad, to level: Awareness) {
        awareness[squad] = max(of(squad), level)
    }

    /// One frame: the meal followed, its witnesses recorded, the reports that are due
    /// heard, and every loss looked at by whoever of its squad has come to it.
    ///
    /// `before` is the bots as the frame found them, `after` as it left them; `prey` is
    /// the bot being coiled round or eaten, if any.
    mutating func step(before: [Interrupts.Glance], after: [Bot], prey: Int?, plan: ScenePlan,
                       bot configuration: BotConfiguration, scoring: ScoringConfiguration, now: Double) {
        let alive = Dictionary(after.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        follow(prey: prey, before: before, after: alive, now: now)
        witness(after: after, plan: plan, configuration: configuration, scoring: scoring, now: now)
        hear(after: alive, now: now)
        look(before: before, after: after, alive: alive, inspection: scoring.inspectionDistance)
    }

    /// Opens a meal where one begins, closes it where it ends, and forgets one nobody
    /// can witness any more.
    private mutating func follow(prey: Int?, before: [Interrupts.Glance], after: [Int: Bot], now: Double) {
        if let open = meals.indices.last, meals[open].ended == nil, meals[open].prey != prey {
            meals[open].ended = now
        }
        if let prey, meals.last.map({ $0.ended != nil || $0.prey != prey }) ?? true,
           let eye = after[prey]?.eye ?? before.first(where: { $0.id == prey })?.eye {
            meals.append(Meal(prey: prey, point: eye))
        }
    }

    /// Records as a witness every living bot that sees where a meal is, from its
    /// beginning to the witness window after its end (FR-SCORE-070), or comes to see it
    /// within the late-arrival window (FR-SCORE-080); each is due to report after the
    /// report delay (FR-SCORE-090). To see it is to see it as a bot sees anything: within
    /// its range and field of view, with nothing in the way (FR-BOT-050, ADR-0060).
    private mutating func witness(after: [Bot], plan: ScenePlan, configuration: BotConfiguration,
                                  scoring: ScoringConfiguration, now: Double) {
        let window = max(scoring.witnessWindow, scoring.lateArrivalWindow)
        meals.removeAll { meal in meal.ended.map { now - $0 > window } ?? false }
        for index in meals.indices {
            for bot in after where bot.isAlive && bot.id != meals[index].prey
                && !meals[index].witnesses.contains(bot.id) {
                guard let range = configuration.archetypes[bot.archetype.rawValue]?.detectionRange,
                      Perception.sees(meals[index].point, from: bot, within: range, plan: plan,
                                      configuration: configuration) else { continue }
                meals[index].witnesses.insert(bot.id)
                reports.append(Report(witness: bot.id, squad: bot.squad, due: now + scoring.reportDelay))
            }
        }
    }

    /// Hears every report that is due from a witness still alive and in the match: one
    /// eaten or killed before it spoke says nothing (FR-SCORE-100, ADR-0060).
    private mutating func hear(after: [Int: Bot], now: Double) {
        for report in reports where report.due <= now && after[report.witness]?.isAlive == true {
            raise(report.squad, to: .confirmed)
        }
        reports.removeAll { $0.due <= now }
    }

    /// Records every squadmate that fell or vanished this frame where it was, and raises
    /// the alarm where a living bot of its squad comes within the inspection distance of
    /// a loss and finds no body there (FR-SCORE-125). A loss whose body is there stays:
    /// the snake may yet take it.
    private mutating func look(before: [Interrupts.Glance], after: [Bot], alive: [Int: Bot], inspection: Double) {
        for was in before where was.isAlive && !(alive[was.id]?.isAlive ?? false) {
            losses[was.id] = Loss(squad: was.squad, point: alive[was.id]?.position ?? was.position)
        }
        let bodies = after.filter { !$0.isAlive }.map(\.position)
        for (id, loss) in losses.sorted(by: { $0.key < $1.key }) {
            guard after.contains(where: { $0.isAlive && $0.squad == loss.squad
                                          && Perception.metres($0.position, loss.point) <= inspection })
            else { continue }
            if !bodies.contains(where: { Perception.metres($0, loss.point) <= inspection }) {
                raise(loss.squad, to: .alarm)
                losses[id] = nil
            }
        }
    }
}
