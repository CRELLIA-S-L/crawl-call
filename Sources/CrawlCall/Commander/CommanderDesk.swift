// Who gets called, when, and what comes back: the half of the commander that lives on
// the match's clock.
//
// One commander per squad (FR-CMD-010) is a matter of state and not of objects: both
// squads are asked through the same surface, and what makes them two commanders is
// that each is handed its own squad's view of the world and its own previous decision,
// and is told nothing of the other's.
//
// A call never happens inside a frame. The match says a call is due, the call runs
// away from the frame, and whatever came back is picked up at the start of a later one
// — which is how NFR-PERF-030 is kept by construction rather than by being careful. The
// clock is the match's and not this type's (E-150's boundary); all this holds is when
// each squad was last called.
//
// file implements: FR-CMD-010, FR-CMD-020, FR-CMD-025, FR-CMD-080
import Foundation

/// Both squads' commanders, the interval between their calls, and what the last call
/// of each came back with.
final class CommanderDesk: @unchecked Sendable {
    /// Kept readable so that a second match can be given the same answerer with a
    /// fresh desk over it (`Game.restarted`).
    let commander: Commander
    /// Seconds between calls to one squad's commander (IF-BOT-010, FR-CMD-020).
    let interval: Double

    private let lock = NSLock()
    /// When each squad was last called, in seconds of the match. A squad never called
    /// has none, and is due at once.
    private var called: [Squad: Double] = [:]
    /// Which squads have a call out. A second call is never started for a squad that
    /// has one running, whatever the clock says.
    private var running: Set<Squad> = []
    /// What came back and has not been applied yet.
    private var answers: [Squad: Result<CommanderDecision, CommanderFailure>] = [:]
    /// The decision each squad's commander last gave, which goes back into its next
    /// call (FR-CMD-025, IF-CMD-010).
    private var last: [Squad: CommanderDecision] = [:]

    init(commander: Commander, interval: Double) {
        self.commander = commander
        self.interval = interval
    }

    /// What each squad's commander said last, for the state its next call carries.
    func lastDecision(of squad: Squad) -> CommanderDecision? {
        lock.lock(); defer { lock.unlock() }
        return last[squad]
    }

    /// Whether a squad's commander is due to be called.
    ///
    /// Three things have to hold, and the third is FR-CMD-080: the two commanders are
    /// scheduled at least half an interval apart, so that two inferences never start
    /// on the same frame. A squad that is already waiting on a call is never called
    /// again, however long it has waited.
    func isDue(_ squad: Squad, at now: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return dueWithoutLocking(squad, at: now)
    }

    private func dueWithoutLocking(_ squad: Squad, at now: Double) -> Bool {
        guard !running.contains(squad) else { return false }
        guard let before = called[squad] else {
            // Never called. The first call of each squad is staggered the same way as
            // every later one: red goes at once, blue half an interval later.
            return squad == .red ? true : now >= interval * Geometry.half
        }
        guard now - before >= interval else { return false }
        // Half an interval from the other's last start, both ways (FR-CMD-080).
        if let other = called[squad.enemy], abs(now - other) < interval * Geometry.half { return false }
        return true
    }

    /// Makes the call and keeps what came back. Awaited by a caller that is not a
    /// frame; the result is picked up later by `take`.
    ///
    /// The lock is taken and dropped in the two synchronous halves below and never in
    /// here: `NSLock.lock()` is unavailable from an asynchronous context and is an
    /// error under the Swift 6 language mode, which is the compiler saying what is
    /// true — a lock a suspension can run across is a lock nobody can reason about.
    func call(_ squad: Squad, with state: CommanderInput, at now: Double) async {
        guard begin(squad, at: now) else { return }
        let answer = await commander.decide(from: state)
        finish(squad, with: answer)
    }

    /// Marks a call as out, or says there already is one.
    private func begin(_ squad: Squad, at now: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !running.contains(squad) else { return false }
        running.insert(squad)
        called[squad] = now
        return true
    }

    /// Keeps what came back, and the decision in it if there was one.
    private func finish(_ squad: Squad, with answer: Result<CommanderDecision, CommanderFailure>) {
        lock.lock(); defer { lock.unlock() }
        running.remove(squad)
        answers[squad] = answer
        if case .success(let decision) = answer { last[squad] = decision }
    }

    /// Everything that has come back and not been applied, and nothing twice.
    func take() -> [(squad: Squad, answer: Result<CommanderDecision, CommanderFailure>)] {
        lock.lock(); defer { lock.unlock() }
        let taken = Squad.allCases.compactMap { squad in
            answers[squad].map { (squad: squad, answer: $0) }
        }
        answers.removeAll()
        return taken
    }

    /// Whether a call is out for this squad.
    func isWaiting(_ squad: Squad) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return running.contains(squad)
    }
}
