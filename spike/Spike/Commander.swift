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
        switch SystemLanguageModel.default.availability {
        case .available: return "model available"
        case .unavailable(let reason): return "model unavailable: \(reason)"
        }
    }

    func start(worldState: @escaping @MainActor () -> String) {
        guard !running, SystemLanguageModel.default.isAvailable else {
            Telemetry.shared.note(availabilityDescription)
            return
        }
        running = true
        task = Task { @MainActor in
            // One session for the whole run, so the prefix (instructions, recent exchanges)
            // stays in the model's cache — `usage.input.cachedTokenCount` shows how much.
            // The context is 4096 tokens: when the transcript nears it, the session is
            // rebuilt from a trimmed transcript (instructions + the last two exchanges).
            var session = LanguageModelSession(instructions: Self.instructions)
            // Warm-up: the first call pays for loading; measured separately.
            await self.call(session: &session, state: worldState(), label: "warmup")
            while self.running {
                try? await Task.sleep(for: self.interval)
                guard self.running else { break }
                await self.call(session: &session, state: worldState(), label: "call")
            }
        }
    }

    static let instructions = """
    You command a squad of six soldiers in a small arena. Another squad fights you. \
    A giant snake may be hunting both squads. Decide the threat, the order and the \
    personality weights for your soldiers from the state you are given. Be terse.
    """
    // The model's cache belongs to the session object (a rebuilt session starts at cached 0),
    // and it is evicted somewhere above ~3000 tokens; an uncached prefill of 1.6–3.3k tokens
    // dropped 9–25 frames, one of ~600 tokens dropped none. So: keep the session while the
    // transcript is small, rebuild to instructions only before eviction, and pass what the
    // commander needs to remember in the state text (the previous order).
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
                session = LanguageModelSession(transcript: Self.trimmed(session.transcript, keepExchanges: Self.keepExchanges))
            }
        } catch let error as LanguageModelSession.GenerationError {
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: false)
            if case .exceededContextWindowSize = error {
                session = LanguageModelSession(transcript: Self.trimmed(session.transcript))
                Telemetry.shared.note("\(label) context exceeded after \(fmt(elapsed)); session rebuilt")
            } else {
                Telemetry.shared.note("\(label) failed after \(fmt(elapsed)): \(error)")
            }
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
