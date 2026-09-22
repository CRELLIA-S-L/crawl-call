// Unattended runs: launched with `--autopilot`, the app drives the snake around a
// fixed route (ramp, upper floor, the drop, between the boxes), switches the
// checks' toggles on a timeline, keeps the screen awake and exits when the run is
// over, so that the CSV in Documents is the whole story. Throwaway code (spike/README.md).
import Foundation
import RealityKit
import UIKit

@MainActor
final class Autopilot {
    static let shared = Autopilot()

    private(set) var enabled = false
    var minutes = 20
    var commander = true
    var repathWindow = 120       // seconds of `repath every frame` at the start
    var tailLength = 40
    private var route: [SIMD3<Float>] = []
    private var next = 0
    private var stallClock: Float = 0
    private var lastDistance: Float = .greatestFiniteMagnitude

    /// Parses the launch arguments. Returns false when not in autopilot mode.
    func configure(arguments: [String]) -> Bool {
        guard arguments.contains("--autopilot") else { return false }
        enabled = true
        func value(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        if let m = value("--minutes").flatMap(Int.init) { minutes = m }
        if let c = value("--commander") { commander = c != "off" }
        if let r = value("--repath-window").flatMap(Int.init) { repathWindow = r }
        if let t = value("--tail").flatMap(Int.init) { tailLength = t }
        if let b = value("--context-budget").flatMap(Int.init) { CommanderLoop.contextBudget = b }
        if let k = value("--keep-exchanges").flatMap(Int.init) { CommanderLoop.keepExchanges = k }
        if let r = value("--register").flatMap(CommanderLoop.Register.init(rawValue:)) { CommanderLoop.register = r }
        // The route, at foot level: up the ramp, across the upper floor, off the ledge, between the boxes, back.
        route = [
            [-6, 0, 0], [-4.6, 0, 1.5], [-4.6, 0, 4], [-3, 0.4, 4], [0, 1.5, 4], [3.5, 2.8, 4],   // up the ramp, clear of the box at (-6, 3)
            [6, 3, 3], [8, 3, 0], [8, 3, -4], [5, 3, -4], [4.6, 3, -4],               // across the upper floor to the ledge
            [4.5, 0, -3], [5, 0, 1], [5, 0, 3.5], [3, 0, 7], [0, 0, 7],               // land east of the cliff wall, round its end
            [-3, 0, 7], [-6, 0, 7], [-10, 0, 3], [-10, 0, -2], [-8, 0, -3],           // the west side
            [-6, 0, -7], [-2, 0, -7], [2, 0, -7], [3, 0, -2], [1, 0, 1], [-2, 0, 0.5], // between the boxes
        ]
        return true
    }

    /// Starts the timeline. `world` provides the toggles.
    func start(world: SpikeWorld) {
        guard enabled else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        world.setTailLength(tailLength)
        BotSystem.repathEveryFrame = repathWindow > 0
        Telemetry.shared.note("autopilot: \(minutes) min, register \(CommanderLoop.register.rawValue), commander \(commander ? "on" : "off"), repath every frame for \(repathWindow) s, tail \(tailLength)")
        if commander { world.commander.start(worldState: { world.worldState() }) }
        Task { @MainActor in
            if repathWindow > 0 {
                try? await Task.sleep(for: .seconds(repathWindow))
                BotSystem.repathEveryFrame = false
                Telemetry.shared.note("autopilot: repath every frame off")
            }
            let remaining = max(0, minutes * 60 - repathWindow)
            try? await Task.sleep(for: .seconds(remaining))
            Telemetry.shared.note("autopilot: run complete, exiting")
            Telemetry.shared.flush()
            try? await Task.sleep(for: .milliseconds(300))
            exit(0)
        }
    }

    /// Called every frame by SnakeSystem: steers toward the next waypoint in screen space.
    func steer(headFoot: SIMD3<Float>, dt: Float) {
        guard enabled, !route.isEmpty else { return }
        let target = route[next]
        let d = SIMD2<Float>(target.x - headFoot.x, target.z - headFoot.z)
        let dist = simd_length(d)
        if dist < 0.6 || stallClock > 4 {
            if stallClock > 4 { Telemetry.shared.note(String(format: "autopilot: stalled before waypoint %d (%.1f, %.1f, %.1f), skipping", next, target.x, target.y, target.z)) }
            next = (next + 1) % route.count
            stallClock = 0; lastDistance = .greatestFiniteMagnitude
            return
        }
        // Progress check: a stall means geometry stopped us (a wall, a box) — skip after 4 s.
        if dist < lastDistance - 0.02 { lastDistance = dist; stallClock = 0 } else { stallClock += dt }
        // Screen space: x right = world +x, y up = world -z.
        SnakeInput.shared.direction = SIMD2<Float>(d.x, -d.y) / dist
    }
}
