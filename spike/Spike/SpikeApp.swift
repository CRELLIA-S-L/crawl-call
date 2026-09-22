// The spike app: one scene, three checks, a HUD. Throwaway code (spike/README.md).
import SwiftUI
import RealityKit

@main
struct SpikeApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup { ContentView() }
    }
}

@MainActor
final class SpikeWorld {
    var root = Entity()
    var head = Entity()
    var commander = CommanderLoop()
    var bots: [Entity] = []

    func build() throws {
        SnakeComponent.registerComponent()
        BotComponent.registerComponent()
        SnakeSystem.registerSystem()
        BotSystem.registerSystem()
        MetricsSystem.registerSystem()

        let arena = try ArenaBuilder.build()
        root = arena.root

        // Snake head
        let headMesh = MeshResource.generateSphere(radius: 0.35)
        let headEntity = ModelEntity(mesh: headMesh, materials: [SimpleMaterial(color: .init(red: 0.8, green: 0.3, blue: 0.05, alpha: 1), isMetallic: false)])
        headEntity.name = "head"
        headEntity.position = ArenaLayout.snakeStart + [0, 0.35, 0]
        headEntity.components.set(NavigationComponent(layer: nil, filter: nil))
        var snake = SnakeComponent()
        snake.radius = 0.3
        headEntity.components.set(snake)
        root.addChild(headEntity)
        snake.controller = try NavigationController(entity: headEntity)
        headEntity.components.set(snake)
        head = headEntity

        let tail = try TailMesh(capacitySamples: 120)
        root.addChild(tail.entity)
        SnakeSystem.tail = tail

        try BotFactory.make(count: 8, into: root)
        bots = root.children.filter { $0.components.has(BotComponent.self) }

        // Light
        let sun = DirectionalLight()
        sun.light.intensity = 3000
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 1)
        sun.look(at: [0, 0, 0], from: [8, 20, 10], relativeTo: nil)
        root.addChild(sun)
    }

    func makeCamera() -> Entity {
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 45
        // 55° below the horizontal, the middle of FR-VIEW-010's range.
        cam.look(at: [0, 0, 0], from: [0, 24, 16.8], relativeTo: nil)
        return cam
    }

    func sendSnake(to point: SIMD3<Float>) {
        guard var s = head.components[SnakeComponent.self], let c = s.controller else { return }
        c.requestPath(to: point)
        s.waitingForPath = true
        head.components.set(s)
        Telemetry.shared.note(String(format: "tap → (%.1f, %.1f, %.1f)", point.x, point.y, point.z))
    }

    func setTailLength(_ n: Int) {
        guard var s = head.components[SnakeComponent.self] else { return }
        s.maxSegments = n
        head.components.set(s)
    }

    func worldState() -> String {
        var lines: [String] = []
        let h = head.position
        lines.append(String(format: "snake at (%.0f, %.0f, %.0f)", h.x, h.y, h.z))
        for (i, b) in bots.enumerated() {
            let p = b.position
            let a = b.components[BotComponent.self]?.action.rawValue ?? "?"
            lines.append(String(format: "soldier %d squad %d at (%.0f, %.0f, %.0f) doing %@", i, i % 2, p.x, p.y, p.z, a))
        }
        lines.append("awareness: alarm — two soldiers vanished without a trace")
        return lines.joined(separator: "\n")
    }
}

struct ContentView: View {
    @State private var world = SpikeWorld()
    @State private var buildError: String?
    @State private var repathEveryFrame = false
    @State private var commanderOn = false
    @State private var tailLength = 40
    private var t: Telemetry { Telemetry.shared }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityView { content in
                do {
                    try world.build()
                    content.add(world.root)
                    content.add(world.makeCamera())
                    content.camera = .virtual
                } catch {
                    buildError = "\(error)"
                }
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        if let p = value.unproject(\.location, to: .scene) {
                            world.sendSnake(to: p)
                        }
                    }
            )
            .ignoresSafeArea()

            hud
        }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let e = buildError { Text("BUILD ERROR: \(e)").foregroundStyle(.red) }
            Text(String(format: "t %ds   fps %.1f   frame max %.1f ms   slow %d (total %d)   thermal %@",
                        t.elapsed, t.fps, t.frameMaxMs, t.slowFrames, t.slowFramesTotal, t.thermal))
            Text(String(format: "deliberation avg %.3f ms  max %.3f ms   path requests/s %d",
                        t.deliberationAvgMs, t.deliberationMaxMs, t.pathRequestsPerSecond))
            Text(String(format: "inference last %.0f ms  max %.0f ms  n=%d fail=%d   worst frame during inference %.1f ms",
                        t.inferenceLastMs, t.inferenceMaxMs, t.inferenceCount, t.inferenceFailures, t.inferenceFrameMaxMs))
            Text(t.lastNote).lineLimit(1)
            HStack(spacing: 12) {
                Toggle("repath every frame", isOn: $repathEveryFrame)
                    .onChange(of: repathEveryFrame) { _, v in BotSystem.repathEveryFrame = v }
                Toggle("commander", isOn: $commanderOn)
                    .onChange(of: commanderOn) { _, v in
                        if v { world.commander.start(worldState: { world.worldState() }) } else { world.commander.stop() }
                    }
                Picker("tail", selection: $tailLength) {
                    Text("10").tag(10); Text("40").tag(40); Text("100").tag(100)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: tailLength) { _, v in world.setTailLength(v) }
            }
            .fixedSize()
            Text("CSV: \(t.csvPath)").font(.caption2)
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(8)
    }
}
