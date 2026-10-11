// The seam: what the game asks a commander for, and the two things that can answer.
//
// There is a protocol here rather than a direct call to the model for one reason that
// is not the test environment. CON-CMD-020 obliges the game to keep working, with no
// voice missing and no order lost, when up to one call in five is refused — and no
// real model refuses on demand, so the only way that constraint can be checked at all
// is an answerer that refuses when it is told to.
//
// Two consequences fall out of it and both are wanted. The suite never waits on an
// inference, which at 2.7 s a call would make the tests something nobody runs. And the
// model's availability stops being a property the code depends on: a device with no
// Apple Intelligence gets `unavailable` through the same path as a refusal, and the
// squad behaves as it does for any other missed cycle.
//
// Nothing in this file imports FoundationModels. The adapter that does is beside it.
//
// file implements: IF-CMD-020
import Foundation

/// Anything that can be asked what a squad should want.
protocol Commander: Sendable {
    /// Whether there is anything to ask. A commander that says no is never called, and
    /// the squad runs without one, exactly as it does after losing its role-holder
    /// (FR-CMD-120).
    var isAvailable: Bool { get }

    /// One call, for one squad, for one interval.
    ///
    /// It never throws: every way a call can fail is a `CommanderFailure` the caller
    /// is expected to survive (CON-CMD-020), and a throwing surface invites a `try?`
    /// that loses which failure it was.
    func decide(from state: CommanderInput) async -> Result<CommanderDecision, CommanderFailure>
}

/// A commander that answers from a script (CON-CMD-020, and every test of the call).
///
/// It is told in advance what to do with each call in turn — answer, refuse, come back
/// malformed, say it is not there — and it says which call it is on, so a test can
/// assert that a refused call was followed by a next one rather than ending the match.
final class ScriptedCommander: Commander, @unchecked Sendable {
    /// What the next call does.
    enum Reply {
        case decision(CommanderDecision)
        case failure(CommanderFailure)
    }

    private let script: [Reply]
    private let loops: Bool
    private var calls = 0
    /// Every state this commander was handed, in order: what a test reads to check
    /// what the commander was told (IF-CMD-010, FR-CMD-070).
    private(set) var heard: [CommanderInput] = []

    /// `loops` repeats the script from the start once it runs out, which is how a
    /// refusal rate is scripted: one refusal in a script of five is one call in five.
    init(_ script: [Reply], loops: Bool = true, available: Bool = true) {
        self.script = script
        self.loops = loops
        self.available = available
    }

    let available: Bool
    var isAvailable: Bool { available }

    var callCount: Int { calls }

    func decide(from state: CommanderInput) async -> Result<CommanderDecision, CommanderFailure> {
        heard.append(state)
        defer { calls += 1 }
        guard !script.isEmpty else { return .failure(.unavailable("the script is empty")) }
        guard loops || calls < script.count else { return .failure(.unavailable("the script is spent")) }
        switch script[calls % script.count] {
        case .decision(let decision): return .success(decision)
        case .failure(let failure): return .failure(failure)
        }
    }
}
