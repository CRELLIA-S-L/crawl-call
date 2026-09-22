// Spike check 2 — eight bots on the navigation mesh with a utility choice of
// action on EVERY frame (the worst case the concept asks to measure), path
// requests on a switch, and path following. Throwaway code (spike/README.md).
import RealityKit
import UIKit

enum BotAction: String, CaseIterable {
    case flee, chase, cover, wander, hold
}

struct BotComponent: Component {
    var controller: NavigationController?
    var action: BotAction = .hold
    var path: [SIMD3<Float>] = []
    var nextNode = 0
    var waitingForPath = false
    var target: SIMD3<Float>?
    var repathClock: Float = 0
    var speed: Float = 3.0
    var panic: Float = 0.5      // personality weight, varied per bot
    var aggression: Float = 0.5
    var seed: UInt64 = 1
}

@MainActor
enum BotFactory {
    static func make(count: Int, into root: Entity) throws {
        let mesh = MeshResource.generateBox(size: [0.5, 1.6, 0.5], cornerRadius: 0.1)
        for i in 0..<count {
            let squad = i % 2
            let color = squad == 0 ? UIColor(red: 0.95, green: 0.42, blue: 0.06, alpha: 1)
                                   : UIColor(red: 0.03, green: 0.62, blue: 0.57, alpha: 1)
            let bot = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
            bot.name = "bot\(i)"
            let x = Float(-6 + i * 2)
            let z: Float = squad == 0 ? -5 : 5
            bot.position = [x, 0.8, z]
            var filter = NavigationComponent.Filter()
            filter.ignoreFlags.setFlag(ArenaLayout.dropFlag)  // bots do not jump off the ledge
            bot.components.set(NavigationComponent(layer: nil, filter: filter))
            var c = BotComponent()
            c.panic = 0.3 + Float(i % 4) * 0.2
            c.aggression = 0.2 + Float((i + 1) % 3) * 0.3
            c.seed = UInt64(1000 + i)
            bot.components.set(c)
            root.addChild(bot)
            // The controller needs the entity in the scene; attach it now that it is.
            c.controller = try NavigationController(entity: bot)
            bot.components.set(c)
        }
    }
}

@MainActor
final class BotSystem: System {
    static let botQuery = EntityQuery(where: .has(BotComponent.self))
    static let snakeQuery = EntityQuery(where: .has(SnakeComponent.self))
    static var repathEveryFrame = false
    static var frozen = false

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard !Self.frozen else { return }
        var headPos = SIMD3<Float>(0, 0, 0)
        for h in context.entities(matching: Self.snakeQuery, updatingSystemWhen: .rendering) { headPos = h.position }

        let clock = ContinuousClock()
        let start = clock.now
        var requests = 0
        for bot in context.entities(matching: Self.botQuery, updatingSystemWhen: .rendering) {
            guard var b = bot.components[BotComponent.self] else { continue }
            deliberate(bot: bot, b: &b, head: headPos, dt: dt, requests: &requests)
            bot.components.set(b)
        }
        let deliberation = clock.now - start
        Telemetry.shared.recordDeliberation(seconds: deliberation, pathRequests: requests)

        for bot in context.entities(matching: Self.botQuery, updatingSystemWhen: .rendering) {
            guard var b = bot.components[BotComponent.self] else { continue }
            execute(bot: bot, b: &b, dt: dt)
            bot.components.set(b)
        }
    }

    // MARK: deliberation — every bot, every frame

    private func deliberate(bot: Entity, b: inout BotComponent, head: SIMD3<Float>, dt: Float, requests: inout Int) {
        let pos = bot.position
        let toHead = head - pos
        let dHead = simd_length(toHead)
        let nearestCover = ArenaLayout.coverBoxes.min { simd_length($0 - pos) < simd_length($1 - pos) }!
        let dCover = simd_length(nearestCover - pos)
        let heightAdvantage = pos.y - head.y

        // Utility per action — the same shape FR-BOT-080/090 describe, deliberately cheap.
        var scores: [BotAction: Float] = [:]
        scores[.flee] = max(0, (8 - dHead) / 8) * (0.5 + b.panic) - max(0, heightAdvantage) * 0.1
        scores[.chase] = (dHead < 14 ? 0.35 : 0) * (0.5 + b.aggression) * (1 - b.panic * 0.5)
        scores[.cover] = max(0, (6 - dCover) / 6) * 0.5 + (dHead < 10 ? 0.2 : 0)
        scores[.wander] = 0.25
        scores[.hold] = 0.2 + (b.path.isEmpty ? 0.05 : 0)
        let best = scores.max { $0.value < $1.value }!.key

        b.repathClock -= dt
        let changed = best != b.action
        let arrived = b.nextNode >= b.path.count && !b.waitingForPath
        if changed || arrived || Self.repathEveryFrame || (b.repathClock <= 0 && best == .chase) {
            b.action = best
            let target: SIMD3<Float>
            switch best {
            case .flee:
                let away = dHead > 0.01 ? -toHead / dHead : SIMD3<Float>(1, 0, 0)
                target = clampToGround(pos + away * 6)
            case .chase:
                target = head
            case .cover:
                target = clampToGround(nearestCover + SIMD3<Float>(0, -0.6, 0.8))
            case .wander:
                target = randomGroundPoint(seed: &b.seed)
            case .hold:
                target = pos
            }
            if best != .hold, let c = b.controller {
                c.requestPath(to: target)
                b.waitingForPath = true
                b.target = target
                requests += 1
            }
            b.repathClock = 0.25
        }
    }

    // MARK: execution — movement along the current path

    private func execute(bot: Entity, b: inout BotComponent, dt: Float) {
        if b.waitingForPath, let c = b.controller {
            switch c.pathfindStatus {
            case .succeeded:
                b.path = c.currentPath.map(\.position)
                b.nextNode = 0
                b.waitingForPath = false
            case .failed:
                b.waitingForPath = false
                b.path = []
            default: break
            }
        }
        var pos = bot.position - SIMD3<Float>(0, 0.8, 0)
        var budget = b.speed * dt
        while budget > 0, b.nextNode < b.path.count {
            let target = b.path[b.nextNode]
            let d = target - pos
            let dist = simd_length(d)
            if dist <= budget { pos = target; budget -= dist; b.nextNode += 1 }
            else { pos += d / dist * budget; budget = 0 }
        }
        bot.position = pos + SIMD3<Float>(0, 0.8, 0)
    }

    private func clampToGround(_ p: SIMD3<Float>) -> SIMD3<Float> {
        [min(max(p.x, ArenaLayout.groundMin.x + 0.5), ArenaLayout.groundMax.x - 0.5), p.y,
         min(max(p.z, ArenaLayout.groundMin.z + 0.5), ArenaLayout.groundMax.z - 0.5)]
    }

    private func randomGroundPoint(seed: inout UInt64) -> SIMD3<Float> {
        func next() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(seed >> 33) / Float(1 << 31)
        }
        // Half the time aim for the upper floor so the ramp gets used.
        if next() < 0.4 {
            return [ArenaLayout.upperMin.x + 0.5 + next() * 7, ArenaLayout.upperY,
                    ArenaLayout.upperMin.z + 0.5 + next() * 15]
        }
        return [ArenaLayout.groundMin.x + 0.5 + next() * 15, 0, ArenaLayout.groundMin.z + 0.5 + next() * 15]
    }
}
