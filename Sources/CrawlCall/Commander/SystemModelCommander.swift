// The commander that really asks the model. The only file in the game that imports
// FoundationModels, which is what makes everything else in `Commander/` testable
// without one.
//
// Every choice here is the spike's or the bench's, not a fresh one — the reasoning is
// in ADR-0017 and `materials/spike/README.md`, and the numbers were reproduced on this
// machine on 2026-10-11:
//
//   * one session per call (FR-CMD-025), because a kept session cost 1150 input tokens
//     against 402, answered slower, and carried a poisoned exchange forward;
//   * the schema in the prompt, because leaving it out saved 206 input tokens and
//     tripled the output, with calls past forty seconds;
//   * `.range` on every weight and no prose on any guide: the prose cost 72 tokens a
//     call and bought nothing, while dropping the range produced 0.8 to 8.0 where the
//     field runs 0 to 1 (IF-CMD-020);
//   * `maximumResponseTokens` from the match configuration (FR-CMD-027), because the
//     bound belongs in a file somebody can turn.
//
// `SystemLanguageModel.default` and not a permissive one: permissive content
// transformations do nothing under guided generation, which is what this uses.
//
// file implements: IF-CMD-020, FR-CMD-025, FR-CMD-027, NFR-PERF-080
import Foundation
import FoundationModels

/// The decision as the model generates it. It is a separate type from
/// `CommanderDecision` on purpose: this one is shaped for the generator — flat, with
/// ranges on the numbers and a string for every choice — and the crossing between the
/// two is where a response is accepted or rejected (IF-CMD-020).
@Generable
struct GeneratedDecision {
    @Generable enum Threat: String { case enemy, snake, withdraw }
    @Generable enum Order: String { case hold, press, flank, withdraw }
    /// The part of the arena the order names, in the words the state uses for a place
    /// (IF-CMD-010), with `nowhere` for an order that names none: the generator has no
    /// optional, so the word carries it.
    @Generable enum Place: String {
        case nowhere
        case middle
        case north = "north side"
        case south = "south side"
        case east = "east side"
        case west = "west side"
        case northEast = "north-east"
        case northWest = "north-west"
        case southEast = "south-east"
        case southWest = "south-west"
    }
    @Generable enum Truce: String { case none, propose, accept, reject }

    var threat: Threat
    var order: Order
    var place: Place
    var truce: Truce
    var speaker: String
    var line: String
}

/// Asks the system language model, once per call, and turns what comes back into the
/// game's own decision — or into the reason there is none.
final class SystemModelCommander: Commander, @unchecked Sendable {
    private let instructions: String
    /// The ceiling of FR-CMD-027, from the match configuration. Readable so a test can
    /// say the shipped number is what reached the adapter.
    let maximumResponseTokens: Int

    private let lock = NSLock()

    /// What the last call spent, as the framework counted it — not as anything here
    /// estimated. `cached` is how much of the input was read from the key-value cache,
    /// which is the number that says whether a session pattern is working at all.
    private(set) var lastUsage: (input: Int, cached: Int, output: Int)?

    init(instructions: String, maximumResponseTokens: Int) {
        self.instructions = instructions
        self.maximumResponseTokens = maximumResponseTokens
    }

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// How much the model can hold, as the model says rather than as anybody measured
    /// once: `contextSize` arrived with iOS 27 and reports 8192 for the on-device
    /// model (Q-540). Nothing in the game hard-codes a window any more.
    var contextSize: Int { SystemLanguageModel.default.contextSize }

    /// Exactly how many tokens a state costs, counted by the model rather than
    /// estimated from its characters (IF-CMD-010). Not on the path of a call — it is a
    /// round trip of its own — but what a check of the budget should use where the
    /// model is at hand.
    func tokenCount(of state: CommanderInput) async -> Int? {
        try? await SystemLanguageModel.default.tokenCount(for: state.prompt)
    }

    private func remember(_ usage: (input: Int, cached: Int, output: Int)) {
        lock.lock(); lastUsage = usage; lock.unlock()
    }

    func decide(from state: CommanderInput) async -> Result<CommanderDecision, CommanderFailure> {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return .failure(.unavailable("the system language model is not available on this device"))
        }
        // A session of its own for this one call (FR-CMD-025): there is no transcript
        // to grow, to overflow the window with, or for a bad exchange to sit in.
        //
        // It is built here and not warmed ahead of time. Warming the next session as
        // soon as the last had answered was tried on 2026-10-12 against the model
        // being loaded forty-one times in ninety seconds, and the phone did not pay
        // for it: 37 loads against 41 over one run each, with the loading time and the
        // median call both a little worse. `prewarm` is a hint the system is free to
        // ignore, and here it did (Q-590).
        let session = LanguageModelSession(model: model, instructions: instructions)
        let options = GenerationOptions(maximumResponseTokens: maximumResponseTokens)
        do {
            let answer = try await session.respond(to: state.prompt,
                                                   generating: GeneratedDecision.self,
                                                   includeSchemaInPrompt: true,
                                                   options: options)
            remember((answer.usage.input.totalTokenCount,
                      answer.usage.input.cachedTokenCount,
                      answer.usage.output.totalTokenCount))
            return SystemModelCommander.read(answer.content)
        } catch let error as LanguageModelError {
            switch error {
            case .refusal: return .failure(.refused)
            case .guardrailViolation: return .failure(.refused)
            case .contextSizeExceeded: return .failure(.malformed("the call did not fit the context"))
            case .timeout: return .failure(.timedOut)
            default: return .failure(.other("\(error)"))
            }
        } catch {
            return .failure(.other("\(error)"))
        }
    }

    /// The crossing: a generated answer becomes the game's decision, or it is rejected.
    ///
    /// Rejection and not repair (IF-CMD-020). The one liberty taken is the word
    /// `nowhere` for a place, which is how an order that names none is carried through
    /// a generator with no optional, and it is part of the shape rather than a repair
    /// of it.
    static func read(_ generated: GeneratedDecision) -> Result<CommanderDecision, CommanderFailure> {
        guard let threat = CommanderDecision.Threat(rawValue: generated.threat.rawValue) else {
            return .failure(.malformed("threat: \(generated.threat.rawValue)"))
        }
        guard let order = CommanderDecision.Order(rawValue: generated.order.rawValue) else {
            return .failure(.malformed("order: \(generated.order.rawValue)"))
        }
        guard let truce = CommanderDecision.Truce(rawValue: generated.truce.rawValue) else {
            return .failure(.malformed("truce: \(generated.truce.rawValue)"))
        }
        let place = generated.place == .nowhere ? nil : Places.Part(rawValue: generated.place.rawValue)
        if generated.place != .nowhere && place == nil {
            return .failure(.malformed("place: \(generated.place.rawValue)"))
        }
        let speaker = generated.speaker.trimmingCharacters(in: .whitespacesAndNewlines)
        let said = generated.line.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = speaker.isEmpty || said.isEmpty
            ? nil : CommanderDecision.Line(speaker: speaker, line: said)
        return .success(CommanderDecision(threat: threat, order: order, place: place,
                                          truce: truce, line: line))
    }

}
