// Birds crossing over the arena (FR-GREENHOLM-030), as a schedule a test can read:
// where each bird of a flock is at a given second, and how far its wings are raised.
// Drawing them is `SceneryBuilder`'s; this decides only where and when.
//
// A bird flies above everything the arena holds, and from the match camera a thing
// that high is seen well beyond where it is: where the line from the camera through it
// meets the floor. So a flight is chosen when it starts, from where the camera then
// looks and how wide its frame then is: its line brought towards the camera by the
// bird's height over the pitch's tangent — the line that is seen crossing the point
// looked at — and its ends just outside the frame at that line, so that the flock
// enters and leaves out of sight on any window, however wide the widest.
//
// implements: FR-GREENHOLM-030
import Foundation
import simd

struct Birds: Equatable {
    /// Seconds from one flight's start to the next's; the first starts one interval
    /// into the match.
    let interval: Double
    /// Birds in a flock, the first leading.
    let count: Int
    /// Metres a second.
    let speed: Double
    /// A bird's length, in metres; its shape and its place in the flock are in these.
    let size: Double
    /// Wingbeats a second.
    let wingbeats: Double
    let colour: SIMD3<Double>
    /// The height they fly at, in metres.
    let height: Double
    /// The match camera the flights are seen through: its shipped pitch, its distance
    /// and its vertical field of view.
    let camera: CameraRange
    /// Metres to either side of the point looked at, in depth, where a flight is to be
    /// seen crossing: half the arena's depth.
    let seen: Double

    /// One crossing.
    struct Flight: Equatable {
        let from: SIMD3<Double>
        let to: SIMD3<Double>
        let starts: Double
        let lasts: Double
        var heading: SIMD3<Double> { simd_normalize(to - from) }
    }

    /// How far behind the leader the last bird flies, in metres.
    var trail: Double { Double(count / BirdShape.arms) * BirdShape.behind * size }

    /// The `number`th crossing, from nought, for a camera looking at `focus` through a
    /// frame `aspect` times as wide as it is tall. Crossings alternate direction, and
    /// each keeps to a line of its own.
    func flight(_ number: Int, lookingAt focus: SIMD3<Double>, aspect: Double) -> Flight {
        let order = Double(number + BirdShape.firstFlight)
        let share = (order * BirdShape.laneStep).truncatingRemainder(dividingBy: Fraction.whole)
        let pitch = camera.pitch * .pi / Geometry.halfTurnDegrees
        // The camera stands this high above the point it looks at, and so this high
        // above the flock; a line off the one through the point is seen further off by
        // the ratio of the two, so the lines are spread over `seen` shrunk by it.
        let eye = camera.distance * sin(pitch)
        let overFlock = eye - (height - focus.y)
        let lift = (height - focus.y) / tan(pitch)
        let spread = overFlock > .zero ? seen * overFlock / eye : .zero
        let z = focus.z + lift + spread * (share * Geometry.bothSides - Fraction.whole)
        // The frame at the farthest line is its depth along the view times the tangent
        // of half the field of view, for each unit of aspect; a flight starts and ends
        // a wingspan beyond it, so that no wing tip shows at either end.
        let depth = max(overFlock / sin(pitch) + spread * cos(pitch), .zero)
        let sight = depth * tan(camera.fieldOfView * .pi / Geometry.fullTurnDegrees)
        let half = sight * aspect + size * BirdShape.wingSpan * Geometry.bothSides
        let west = SIMD3(focus.x - half, height, z)
        let east = SIMD3(focus.x + half, height, z)
        let eastward = number.isMultiple(of: BirdShape.directions)
        let from = eastward ? west : east
        let to = eastward ? east : west
        let lasts = (simd_distance(from, to) + trail) / speed
        return Flight(from: from, to: to, starts: order * interval, lasts: min(lasts, interval))
    }

    /// The crossing under way at `time` seconds into the match, by number, if one is;
    /// its line is the caller's to choose, since it depends on the camera.
    func number(at time: Double) -> Int? {
        // A configuration with no interval has no flights, rather than one every instant.
        guard interval > .zero else { return nil }
        let number = Int((time / interval).rounded(.down)) - BirdShape.firstFlight
        return number >= .zero ? number : nil
    }

    /// Where each bird of a flight is at `time` seconds into the match, leader first,
    /// with the way they fly; nil outside the flight.
    func flock(at time: Double, on flight: Flight) -> (positions: [SIMD3<Double>], heading: SIMD3<Double>)? {
        let into = time - flight.starts
        guard into >= .zero, into < flight.lasts else { return nil }
        let heading = flight.heading
        let leader = flight.from + heading * (into * speed)
        let side = SIMD3(-heading.z, Fraction.none, heading.x)
        var positions: [SIMD3<Double>] = []
        for index in Int.zero..<count {
            // The V: the second and third bird one rank behind the leader, to its
            // left and right, the fourth and fifth a rank further, and so on.
            let rank = Double((index + BirdShape.leaders) / BirdShape.arms)
            let hand = index.isMultiple(of: BirdShape.arms) ? Geometry.aboveSide : Geometry.belowSide
            positions.append(leader - heading * (rank * BirdShape.behind * size)
                             + side * (hand * rank * BirdShape.beside * size))
        }
        return (positions, heading)
    }

    /// How far a wing is raised at `time`, in degrees: up and down about level.
    func wing(at time: Double) -> Double {
        BirdShape.flapDegrees * sin(Geometry.bothSides * .pi * wingbeats * time)
    }
}
