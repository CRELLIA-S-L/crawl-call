// Spike check 3 — one Foundation Models call beside rendering, on an interval,
// with guided generation into a structure shaped like IF-CMD-020.
// Throwaway code (spike/README.md).
import FoundationModels
import Foundation

@Generable(description: "A squad commander's tactical decision")
struct CommanderOrder {
    @Generable enum Threat: String { case enemy, snake, withdraw }
    @Generable enum Order: String { case hold, flank, withdrawToZone, disperse, destroyCover }

    @Guide(description: "What the squad treats as the main threat right now")
    var threat: Threat
    @Guide(description: "The order for the whole squad")
    var order: Order
    @Guide(description: "Aggression weight for the squad, 0 to 1", .range(0...1))
    var aggression: Double
    @Guide(description: "Discipline weight for the squad, 0 to 1", .range(0...1))
    var discipline: Double
    @Guide(description: "Panic weight for the squad, 0 to 1", .range(0...1))
    var panic: Double
    @Guide(description: "One short line the commander shouts to the squad, in English")
    var callout: String
}

@MainActor
final class CommanderLoop {
    private(set) var running = false
    private var task: Task<Void, Never>?
    var interval: Duration = .seconds(7)

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
            // One session for the whole run, so the prefix (instructions, recent exchanges)
            // stays in the model's cache — `usage.input.cachedTokenCount` shows how much.
            // The context is 4096 tokens: when the transcript nears it, the session is
            // rebuilt from a trimmed transcript (instructions + the last two exchanges).
            var session = LanguageModelSession(model: Self.model, instructions: Self.instructions)
            // Warm-up: the first call pays for loading; measured separately.
            await self.call(session: &session, state: worldState(), label: "warmup")
            while self.running {
                try? await Task.sleep(for: self.interval)
                guard self.running else { break }
                await self.call(session: &session, state: worldState(), label: "call")
            }
        }
    }

    // The game is soldiers under attack: the default guardrails refused a callout after
    // ten minutes of play and then every following call, since the refusal stayed in the
    // transcript. `permissiveContentTransformations` is the setting Apple provides for
    // content the app itself is responsible for (our own filter stays: CON-PUB-080).
    static let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)

    /// Two registers, to be compared: the military one this spike started with, and the
    /// comedy one the concept asks for (§2, F-030, ADR-0002 — Overcooked, not a war film).
    enum Register: String { case military, comedy }
    static var register: Register = .comedy   // the register ADR-0017 chose; --register military replays the comparison

    static var instructions: String {
        switch register {
        case .military:
            return """
            You command a squad of six soldiers in a small arena. Another squad fights you. \
            A giant snake may be hunting both squads. Decide the threat, the order and the \
            personality weights for your soldiers from the state you are given. Be terse.
            """
        case .comedy:
            return """
            You are in charge of six clumsy toy soldiers in a bright cluttered arena, like a \
            kitchen in a cartoon. A rival crew is making a mess of the same place. A huge \
            googly-eyed snake is swallowing people whole — boots sticking out, no blood, \
            nothing gruesome, pure slapstick. Your crew has names: Davis, Pike, Marsh, Otto, \
            Beans and Kit. Pick what to worry about, what the crew should do, and how rattled \
            each of them is. The callout is one short line somebody yells in a panic — name \
            people, blame the other crew, react to how ridiculous this is. Never describe \
            weapons, wounds or dying; people get gulped, bounced, or vanish with a yelp.
            """
        }
    }

    // The model's cache belongs to the session object (a rebuilt session starts at cached 0)
    // and is evicted somewhere above ~3000 tokens; an uncached prefill of 1.6–3.3k tokens
    // dropped 9–25 frames, one of ~600 tokens dropped none. So the session is kept while its
    // transcript is small and rebuilt to instructions only before eviction (CON-CMD-010).
    static var contextBudget = 2000
    static var keepExchanges = 0
    private(set) var lastOrder: String = "none yet"

    /// Instructions plus the last `keepExchanges` prompt/response pairs.
    static func trimmed(_ t: Transcript, keepExchanges: Int = 2) -> Transcript {
        var entries: [Transcript.Entry] = t.filter { if case .instructions = $0 { return true } else { return false } }
        let tail = t.filter { if case .instructions = $0 { return false } else { return true } }
        entries += tail.suffix(keepExchanges * 2)
        return Transcript(entries: entries)
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
    }

    private func call(session: inout LanguageModelSession, state: String, label: String) async {
        let clock = ContinuousClock()
        Telemetry.shared.inferenceBegan()
        let start = clock.now
        do {
            let response = try await session.respond(to: "Current state:\n\(state)\nDecide.", generating: CommanderOrder.self)
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: true)
            let o = response.content
            let u = response.usage
            lastOrder = "\(o.threat.rawValue)/\(o.order.rawValue)"
            Telemetry.shared.note("\(label) \(fmt(elapsed)) in \(u.input.totalTokenCount) tok (cached \(u.input.cachedTokenCount)) out \(u.output.totalTokenCount) \(o.threat.rawValue)/\(o.order.rawValue) a\(o.aggression) d\(o.discipline) p\(o.panic) \"\(o.callout)\"")
            if u.input.totalTokenCount > Self.contextBudget {
                session = LanguageModelSession(model: Self.model, transcript: Self.trimmed(session.transcript, keepExchanges: Self.keepExchanges))
            }
        } catch let error as LanguageModelError {
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: false)
            // Any failure poisons the transcript: the refused prompt stays in it and every
            // later call re-sends it, which is how one guardrail trip became 84 in a row.
            // Rebuild from the instructions and carry on.
            let kind: String
            switch error {
            case .guardrailViolation(let v): kind = "guardrail: \(v.debugDescription)"
            case .refusal(let r): kind = "refusal: \(r.debugDescription)"
            case .contextSizeExceeded: kind = "context exceeded"
            case .rateLimited: kind = "rate limited"
            case .timeout: kind = "timeout"
            default: kind = "\(error)"
            }
            session = LanguageModelSession(model: Self.model, instructions: Self.instructions)
            Telemetry.shared.note("\(label) failed after \(fmt(elapsed)) — \(kind); session rebuilt")
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
