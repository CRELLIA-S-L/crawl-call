// What each frame of a match cost and what happened in it (FR-TOOL-230), kept in a ring
// of fixed size so that recording a frame allocates nothing and cannot itself be the
// spike it looks for, and written as CSV (FR-TOOL-240).
//
// implements: FR-TOOL-230, FR-TOOL-240
import Foundation

/// What a frame's own step spends its time on. `step` is the match's whole step and
/// holds `deliberation`; the others follow it.
enum FramePhase: Int, CaseIterable {
    case step, deliberation, seeThrough, draw
}

struct FrameRecord {
    struct Frame: Equatable {
        /// Milliseconds since the record began.
        var time: Double = .zero
        /// Milliseconds since the frame before, as the renderer measured it.
        var interval: Double = .zero
        /// Milliseconds spent in each phase, by `FramePhase.rawValue`.
        var phases = SIMD4<Double>.zero
        /// The device's thermal state as the system reported it when the frame was
        /// drawn: what says whether a slow stretch is the device throttling itself.
        var thermal: ProcessInfo.ThermalState = .nominal
        /// How many times each event happened, by its place in `FrameEvent.allCases`.
        var events = SIMD8<UInt16>.zero

        subscript(phase: FramePhase) -> Double {
            get { phases[phase.rawValue] }
            set { phases[phase.rawValue] = newValue }
        }

        func count(of event: FrameEvent) -> Int { Int(events[FrameRecord.slot(of: event)]) }

        /// Counts an event, saturating rather than wrapping at the counter's limit.
        mutating func add(_ event: FrameEvent, times: Int = FrameRecording.once) {
            let slot = FrameRecord.slot(of: event)
            events[slot] = UInt16(clamping: Int(events[slot]) + times)
        }
    }

    let capacity: Int
    /// The frames, oldest first once `start` is taken into account.
    private var ring: [Frame]
    private var start = Int.zero
    private(set) var count = Int.zero
    /// Frames recorded and since overwritten because the ring was full.
    private(set) var dropped = Int.zero

    init(capacity: Int = FrameRecording.capacity) {
        self.capacity = max(capacity, FrameRecording.smallestCapacity)
        ring = Array(repeating: Frame(), count: self.capacity)
    }

    mutating func record(_ frame: Frame) {
        if count < capacity {
            ring[(start + count) % capacity] = frame
            count += FrameRecording.framesPerRecord
        } else {
            ring[start] = frame
            start = (start + FrameRecording.framesPerRecord) % capacity
            dropped += FrameRecording.framesPerRecord
        }
    }

    /// The frames kept, oldest first.
    var frames: [Frame] { (Int.zero..<count).map { ring[(start + $0) % capacity] } }

    /// The record as CSV: a header, then a row per frame kept, numbered from the
    /// first frame ever recorded so that a gap left by the ring shows.
    func csv() -> String {
        var text = FrameRecording.header + FrameRecording.lineBreak
        for (offset, frame) in frames.enumerated() {
            let columns = [String(dropped + offset + FrameRecording.firstFrameNumber),
                           Self.time(frame.time), Self.time(frame.interval),
                           Self.time(frame[.step]), Self.time(frame[.deliberation]),
                           Self.time(frame[.seeThrough]), Self.time(frame[.draw]),
                           Self.thermal(frame.thermal), Self.events(of: frame)]
            text += columns.joined(separator: FrameRecording.columnSeparator) + FrameRecording.lineBreak
        }
        return text
    }

    static func slot(of event: FrameEvent) -> Int {
        FrameEvent.allCases.firstIndex(of: event) ?? Int.zero
    }

    private static func time(_ milliseconds: Double) -> String {
        String(format: FrameRecording.timeFormat, milliseconds)
    }

    static func thermal(_ state: ProcessInfo.ThermalState) -> String {
        FrameRecording.thermalNames.indices.contains(state.rawValue)
            ? FrameRecording.thermalNames[state.rawValue] : FrameRecording.unknownThermal
    }

    private static func events(of frame: Frame) -> String {
        FrameEvent.allCases.compactMap { event -> String? in
            let n = frame.count(of: event)
            guard n > Int.zero else { return nil }
            return n == FrameRecording.once ? event.rawValue : event.rawValue + FrameRecording.countMark + String(n)
        }.joined(separator: FrameRecording.eventSeparator)
    }
}
