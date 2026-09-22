// Spike check 3 — one Foundation Models call beside rendering, on an interval,
// with guided generation into a structure shaped like IF-CMD-020.
// Throwaway code (spike/README.md).
import FoundationModels
import Foundation

// Guides carry constraints, not prose: the bench measured the description text at about
// 72 tokens per call with no benefit — the bare `.range` tracked the situation better
// (spike/README.md, ADR-0017).
@Generable
struct CommanderOrder {
    @Generable enum Threat: String { case enemy, snake, withdraw }
    @Generable enum Order: String { case hold, flank, withdrawToZone, disperse, destroyCover }

    var threat: Threat
    var order: Order
    @Guide(.range(0...1)) var aggression: Double
    @Guide(.range(0...1)) var discipline: Double
    @Guide(.range(0...1)) var panic: Double
    var speaker: String
    var callout: String
}


@MainActor
final class CommanderLoop {
    private(set) var running = false
    private var task: Task<Void, Never>?
    var interval: Duration = .seconds(7)
    /// The commander's continuity lives here, not in a transcript: it goes back into the
    /// world state on the next call (FR-CMD-025).
    private(set) var lastOrder: String = "none yet"

    var availabilityDescription: String {
        switch Self.model.availability {
        case .available: return "model available"
        case .unavailable(let reason): return "model unavailable: \(reason)"
        }
    }

    func start(worldState: @escaping @MainActor () -> String) {
        guard !running, Self.model.isAvailable else {
            Telemetry.shared.note(availabilityDescription)
            return
        }
        running = true
        task = Task { @MainActor in
            // A fresh session per call: measured against a kept session it costs a third of
            // the tokens (402 against a mean of 1156), answers faster (1.6 s against 2.0 s),
            // and cannot carry a refused exchange into the next call at all (ADR-0017).
            await self.call(state: worldState(), label: "warmup")
            while self.running {
                try? await Task.sleep(for: self.interval)
                guard self.running else { break }
                await self.call(state: worldState(), label: "call")
            }
        }
    }

    // The default guardrails, deliberately: `permissiveContentTransformations` is documented
    // as applying to string generation only — "when you use guided generation, the framework
    // runs the default guardrails against model input and output as usual" — and this call is
    // guided. What removed the blocks was the register and the state's vocabulary (ADR-0017).
    static let model = SystemLanguageModel.default

    /// Two registers, to be compared: the military one this spike started with, and the
    /// comedy one the concept asks for (§2, F-030, ADR-0002 — Overcooked, not a war film).
    enum Register: String { case military, comedy }
    static var register: Register = .comedy   // ADR-0017; --register military replays the comparison

    static var instructions: String {
        switch register {
        case .military:
            return """
            You command a squad of six soldiers in a small arena. Another squad fights you. \
            A giant snake may be hunting both squads. Decide the threat, the order and the \
            personality weights for your soldiers from the state you are given. Be terse.
            """
        case .comedy:
            // The measured instructions (ADR-0017): a role and its domain first, as Apple's
            // guidance for reducing over-blocking asks, uppercase for the one phrase that
            // matters, and no vocabulary the guardrail reads as violence. 0 blocked calls in
            // 100 against 10 in 100 for the text this replaced, at 91 tokens instead of 148.
            return """
            You write dialogue for a silly cartoon game. Toy figures scurry around a playroom \
            while a googly-eyed snake puppet chases them. It is HARMLESS SLAPSTICK: figures get \
            scooped up and pop back out, like a cartoon. Choose what the crew worries about, \
            what they do, how flustered they are, and one short funny line somebody yells. \
            The crew are Davis, Pike, Marsh, Otto, Beans and Kit.
            """
        }
    }

    // The model's cache belongs to the session object (a rebuilt session starts at cached 0)
    // and is evicted somewhere above ~3000 tokens; an uncached prefill of 1.6–3.3k tokens
    // dropped 9–25 frames, one of ~600 tokens dropped none. So the session is kept while its
    // transcript is small and rebuilt to instructions only before eviction (CON-CMD-010).
    static var maxOutputTokens = 80

    func stop() {
        running = false
        task?.cancel()
        task = nil
    }

    private func call(state: String, label: String) async {
        let clock = ContinuousClock()
        Telemetry.shared.inferenceBegan()
        let start = clock.now
        let session = LanguageModelSession(model: Self.model, instructions: Self.instructions)
        do {
            // The schema stays in the prompt: dropping it saved 206 input tokens but tripled
            // the output and produced a 43-second call — and the documented default is `true`.
            let response = try await session.respond(to: "Situation:\n\(state)\nDecide.",
                                                     generating: CommanderOrder.self,
                                                     options: GenerationOptions(maximumResponseTokens: Self.maxOutputTokens))
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: true)
            let o = response.content
            let u = response.usage
            lastOrder = "\(o.threat.rawValue)/\(o.order.rawValue)"
            Telemetry.shared.note("\(label) \(fmt(elapsed)) in \(u.input.totalTokenCount) tok (cached \(u.input.cachedTokenCount)) out \(u.output.totalTokenCount) \(lastOrder) a\(o.aggression) d\(o.discipline) p\(o.panic) \"\(o.speaker): \(o.callout)\"")
        } catch let error as LanguageModelError {
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: false)
            let kind: String
            switch error {
            case .guardrailViolation(let v): kind = "guardrail: \(v.debugDescription)"
            case .refusal(let r): kind = "refusal: \(r.debugDescription)"
            case .contextSizeExceeded: kind = "context exceeded"
            case .rateLimited: kind = "rate limited"
            case .timeout: kind = "timeout"
            default: kind = "\(error)"
            }
            // Nothing to rebuild: the session belonged to this call. The game plays a
            // pre-written line instead (FR-CMD-165).
            Telemetry.shared.note("\(label) failed after \(fmt(elapsed)) — \(kind)")
        } catch {
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: false)
            Telemetry.shared.note("\(label) failed after \(fmt(elapsed)): \(error)")
        }
    }

    private func fmt(_ d: Duration) -> String {
        let ms = Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
        return String(format: "%.0f ms", ms)
    }
}
