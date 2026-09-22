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
    var grid: NavGrid?

    func build() throws {
        SnakeComponent.registerComponent()
        BotComponent.registerComponent()
        SnakeSystem.registerSystem()
        BotSystem.registerSystem()
        MetricsSystem.registerSystem()

        let arena = try ArenaBuilder.build()
        root = arena.root
        BotSystem.grid = arena.grid
        grid = arena.grid

        // Snake head: a character controller capsule, steered by the joystick.
        let headMesh = MeshResource.generateSphere(radius: 0.35)
        let headEntity = ModelEntity(mesh: headMesh, materials: [SimpleMaterial(color: .init(red: 0.8, green: 0.3, blue: 0.05, alpha: 1), isMetallic: false)])
        headEntity.name = "head"
        headEntity.position = ArenaLayout.snakeStart + [0, 0.5, 0]
        headEntity.components.set(CharacterControllerComponent(radius: 0.3, height: 0.6, slopeLimit: 50 * .pi / 180, stepLimit: ArenaLayout.stepLimit))
        var snake = SnakeComponent()
        snake.radius = 0.3
        headEntity.components.set(snake)
        root.addChild(headEntity)
        head = headEntity
        probeGraph()

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

    /// Startup probe: the same paths that broke on RealityKit's navmesh, now over the grid.
    func probeGraph() {
        guard let grid else { return }
        let probes: [(String, SIMD3<Float>, SIMD3<Float>, Int?)] = [
            ("ground→ramp top", [-6, 0, 4], [3.5, 2.8, 4], ArenaLayout.dropFlag),
            ("ramp top→upper near seam", [3.5, 2.8, 4], [4.8, 3, 4], ArenaLayout.dropFlag),
            ("ramp mid→upper far", [0, 1.5, 4], [9, 3, 0], ArenaLayout.dropFlag),
            ("upper→upper", [6, 3, -6], [11, 3, 6], ArenaLayout.dropFlag),
            ("upper→ground (bot, drop ignored)", [5, 3, -4], [1, 0, -4], ArenaLayout.dropFlag),
            ("upper→ground (snake, drop allowed)", [5, 3, -4], [1, 0, -4], nil),
            ("A upper→upper (wall half)", [6, 3, -6], [10, 3, -2], ArenaLayout.dropFlag),
            ("A ground→ground (wall half)", [6, 0, -6], [10, 0, -2], ArenaLayout.dropFlag),
            ("B upper→upper (ramp half)", [6, 3, 6], [10, 3, 3], ArenaLayout.dropFlag),
            ("B ground→ground (ramp half)", [6, 0, 6], [10, 0, 3], ArenaLayout.dropFlag),
        ]
        let clock = ContinuousClock()
        for (name, a, b, flag) in probes {
            let t0 = clock.now
            let path = grid.path(from: a, to: b, ignoreFlag: flag)
            let us = Double((clock.now - t0).components.attoseconds) / 1e12
            if let path {
                let ys = path.map { String(format: "%.1f", $0.y) }.joined(separator: " ")
                let end = path.last ?? a
                let reached = simd_length(SIMD2<Float>(end.x - b.x, end.z - b.z)) < ArenaLayout.cellSize && abs(end.y - b.y) < 0.5
                Telemetry.shared.note(String(format: "probe %@: %d nodes %@ %.0f µs y: %@", name, path.count, reached ? "REACHED" : "SHORT", us, ys))
            } else {
                Telemetry.shared.note("probe \(name): unreachable")
            }
        }
    }

    func makeCamera() -> Entity {
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 45
        // 55° below the horizontal, the middle of FR-VIEW-010's range.
        cam.look(at: [0, 0, 0], from: [0, 24, 16.8], relativeTo: nil)
        return cam
    }

    func setTailLength(_ n: Int) {
        guard var s = head.components[SnakeComponent.self] else { return }
        s.maxSegments = n
        head.components.set(s)
    }

    /// The state the model reads. Its vocabulary is part of the contract (IF-CMD-010,
    /// IF-CMD-060): the guardrail checks this text too, and the words come back out in the
    /// line. "figures", not "soldiers"; "gone", not "dead" (ADR-0017).
    func worldState() -> String {
        var lines: [String] = []
        let h = head.position
        lines.append(String(format: "snake puppet at (%.0f, %.0f, %.0f)", h.x, h.y, h.z))
        for (i, b) in bots.enumerated() {
            let p = b.position
            let a = b.components[BotComponent.self]?.action.rawValue ?? "?"
            lines.append(String(format: "figure %d, crew %d, at (%.0f, %.0f, %.0f), %@", i, i % 2, p.x, p.y, p.z, a))
        }
        lines.append("two of the crew have gone missing, nobody saw where")
        lines.append("your last call: \(commander.lastOrder)")
        return lines.joined(separator: "\n")
    }
}

struct ContentView: View {
    @State private var world = SpikeWorld()
    @State private var buildError: String?
    @State private var repathEveryFrame = false
    @State private var commanderOn = false
    @State private var tailLength = 40
    @State private var inspect = false
    private var t: Telemetry { Telemetry.shared }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityView { content in
                do {
                    try world.build()
                    content.add(world.root)
                    content.add(world.makeCamera())
                    content.camera = .virtual
                    content.cameraTarget = world.root
                    if Autopilot.shared.configure(arguments: ProcessInfo.processInfo.arguments) {
                        Autopilot.shared.start(world: world)
                    }
                } catch {
                    buildError = "\(error)"
                }
            }
            .realityViewCameraControls(inspect ? .orbit : .none)
            .ignoresSafeArea()

            hud
            if !inspect && !Autopilot.shared.enabled { joystick }
        }
    }

    @State private var stickOffset = CGSize.zero
    private let stickRadius: CGFloat = 60

    /// A virtual joystick bottom-left: the held direction, normalised to the ring.
    private var joystick: some View {
        VStack {
            Spacer()
            HStack {
                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: stickRadius * 2 + 40, height: stickRadius * 2 + 40)
                    Circle().fill(.white.opacity(0.5)).frame(width: 56, height: 56).offset(stickOffset)
                }
                .padding(28)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            var v = SIMD2<Float>(Float(g.translation.width), Float(-g.translation.height))
                            let len = simd_length(v)
                            if len > Float(stickRadius) { v = v / len * Float(stickRadius) }
                            stickOffset = CGSize(width: CGFloat(v.x), height: CGFloat(-v.y))
                            SnakeInput.shared.direction = len < 8 ? .zero : v / Float(stickRadius)
                        }
                        .onEnded { _ in
                            stickOffset = .zero
                            SnakeInput.shared.direction = .zero
                        }
                )
                Spacer()
            }
        }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let e = buildError { Text("BUILD ERROR: \(e)").foregroundStyle(.red) }
            Text(String(format: "t %ds   fps %.1f   frame max %.1f ms   slow %d (total %d)   thermal %@",
                        t.elapsed, t.fps, t.frameMaxMs, t.slowFrames, t.slowFramesTotal, t.thermal))
            Text(String(format: "vsync fps %.1f   vsync max %.1f ms   dropped %d (total %d)", t.vsyncFps, t.vsyncMaxMs, t.vsyncDropped, t.vsyncDroppedTotal))
            Text(String(format: "deliberation avg %.3f ms  max %.3f ms   path requests/s %d  failures/s %d  slowest path %.2f ms",
                        t.deliberationAvgMs, t.deliberationMaxMs, t.pathRequestsPerSecond, t.pathFailures, t.pathMaxMs))
            Text(String(format: "inference last %.0f ms  max %.0f ms  n=%d fail=%d   worst frame during inference %.1f ms",
                        t.inferenceLastMs, t.inferenceMaxMs, t.inferenceCount, t.inferenceFailures, t.inferenceFrameMaxMs))
            Text(t.lastNote).lineLimit(1)
            HStack(spacing: 12) {
                Toggle("repath every frame", isOn: $repathEveryFrame)
                    .onChange(of: repathEveryFrame) { _, v in BotSystem.repathEveryFrame = v }
                Toggle("inspect", isOn: $inspect)
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
