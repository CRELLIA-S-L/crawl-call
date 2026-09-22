// Telemetry for the spike: per-second frame statistics, deliberation cost,
// inference latency, thermal state — shown on screen and appended to a CSV in
// the app's Documents folder for the A write-ups. Throwaway code (spike/README.md).
import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class Telemetry {
    static let shared = Telemetry()

    // Shown on the HUD
    var fps: Double = 0
    var frameMaxMs: Double = 0
    var slowFrames = 0            // frames over 16.6 ms in the last second
    var slowFramesTotal = 0
    var deliberationAvgMs: Double = 0
    var deliberationMaxMs: Double = 0
    var pathRequestsPerSecond = 0
    var inferenceLastMs: Double = 0
    var inferenceMaxMs: Double = 0
    var inferenceCount = 0
    var inferenceFailures = 0
    var inferenceFrameMaxMs: Double = 0   // worst frame while an inference was running
    var thermal: String = "nominal"
    var elapsed: Int = 0
    var lastNote: String = ""
    var csvPath: String = ""

    // Accumulators for the current second
    private var frames = 0
    private var secondAccum: Double = 0
    private var frameMaxThisSecond: Double = 0
    private var slowThisSecond = 0
    private var delibSum: Double = 0
    private var delibMax: Double = 0
    private var delibCount = 0
    private var pathRequests = 0
    private var inferenceActive = false
    private var startDate = Date()
    private var csv: FileHandle?

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        let url = dir.appendingPathComponent("spike-\(f.string(from: Date())).csv")
        let header = "t,fps,frame_max_ms,slow_frames,delib_avg_ms,delib_max_ms,path_requests,infer_last_ms,infer_max_ms,infer_frame_max_ms,infer_active,thermal\n"
        try? header.write(to: url, atomically: true, encoding: .utf8)
        csv = try? FileHandle(forWritingTo: url)
        csv?.seekToEndOfFile()
        csvPath = url.lastPathComponent
    }

    func frame(dt: Double) {
        frames += 1
        secondAccum += dt
        let ms = dt * 1000
        frameMaxThisSecond = max(frameMaxThisSecond, ms)
        if ms > 16.7 { slowThisSecond += 1 }
        if inferenceActive { inferenceFrameMaxMs = max(inferenceFrameMaxMs, ms) }
        if secondAccum >= 1 {
            fps = Double(frames) / secondAccum
            frameMaxMs = frameMaxThisSecond
            slowFrames = slowThisSecond
            slowFramesTotal += slowThisSecond
            deliberationAvgMs = delibCount > 0 ? delibSum / Double(delibCount) : 0
            deliberationMaxMs = delibMax
            pathRequestsPerSecond = pathRequests
            elapsed = Int(Date().timeIntervalSince(startDate))
            let state = ProcessInfo.processInfo.thermalState
            thermal = ["nominal", "fair", "serious", "critical"][min(state.rawValue, 3)]
            let row = String(format: "%d,%.1f,%.2f,%d,%.3f,%.3f,%d,%.0f,%.0f,%.2f,%d,%@\n",
                             elapsed, fps, frameMaxMs, slowFrames, deliberationAvgMs, deliberationMaxMs,
                             pathRequestsPerSecond, inferenceLastMs, inferenceMaxMs, inferenceFrameMaxMs,
                             inferenceActive ? 1 : 0, thermal)
            csv?.write(row.data(using: .utf8)!)
            print("[spike] " + row, terminator: "")
            frames = 0; secondAccum = 0; frameMaxThisSecond = 0; slowThisSecond = 0
            delibSum = 0; delibMax = 0; delibCount = 0; pathRequests = 0
        }
    }

    func recordDeliberation(seconds d: Duration, pathRequests n: Int) {
        let ms = Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
        delibSum += ms; delibMax = max(delibMax, ms); delibCount += 1
        pathRequests += n
    }

    func inferenceBegan() { inferenceActive = true }

    func inferenceEnded(seconds d: Duration, ok: Bool) {
        inferenceActive = false
        let ms = Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
        inferenceLastMs = ms
        inferenceMaxMs = max(inferenceMaxMs, ms)
        inferenceCount += 1
        if !ok { inferenceFailures += 1 }
    }

    func note(_ s: String) {
        lastNote = s
        print("[spike] " + s)
    }
}

/// Counts frames; registered last so its deltaTime is the whole frame's.
@MainActor
final class MetricsSystem: System {
    init(scene: RealityKit.Scene) {}
    func update(context: SceneUpdateContext) {
        Telemetry.shared.frame(dt: context.deltaTime)
    }
}
