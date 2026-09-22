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
            let session = LanguageModelSession(instructions: """
            You command a squad of six soldiers in a small arena. Another squad fights you. \
            A giant snake may be hunting both squads. Decide the threat, the order and the \
            personality weights for your soldiers from the state you are given. Be terse.
            """)
            // Warm-up: the first call pays for loading; measured separately.
            await self.call(session: session, state: worldState(), label: "warmup")
            while self.running {
                try? await Task.sleep(for: self.interval)
                guard self.running else { break }
                await self.call(session: session, state: worldState(), label: "call")
            }
        }
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
    }

    private func call(session: LanguageModelSession, state: String, label: String) async {
        let clock = ContinuousClock()
        Telemetry.shared.inferenceBegan()
        let start = clock.now
        do {
            let response = try await session.respond(to: "Current state:\n\(state)\nDecide.", generating: CommanderOrder.self)
            let elapsed = clock.now - start
            Telemetry.shared.inferenceEnded(seconds: elapsed, ok: true)
            let o = response.content
            Telemetry.shared.note("\(label) \(fmt(elapsed)) \(o.threat.rawValue)/\(o.order.rawValue) a\(o.aggression) d\(o.discipline) p\(o.panic) \"\(o.callout)\"")
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
