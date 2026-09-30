// The snake's body as one smooth tube (FR-VIEW-250): its line runs through the head
// and every point the tail lays down, curved between them, and the tube round it
// rests on the surface, is rounded off at the head and narrows towards the tail's end.
// Only geometry, in world metres: `SnakeEntity` puts it on screen, and a test reads
// it as it is.
//
// The tube is a stack of rings. Each ring's frame is carried from the one before it
// rather than set against the world's up, so that the tube does not twist where the
// line turns, climbs or drops straight down a ledge.
//
// implements: FR-VIEW-250, FR-VIEW-260, FR-VIEW-270, FR-VIEW-280, FR-VIEW-330
import Foundation
import simd

struct SnakeBody: Equatable {
    /// Every vertex, its outward normal, and where it lies on the body: metres along
    /// the line from the head's end, and the share of the way round the tube.
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var surface: [SIMD2<Float>] = []
    /// Three indices a triangle, facing out.
    var indices: [UInt32] = []

    var triangles: Int { indices.count / Square.triangle }

    /// How a crawling body sways (FR-VIEW-330): side to side of its line by
    /// `amplitude`, one wave to every `wavelength` metres of ground, `crawled` being how
    /// far the head has come. The wave is the ground's: a point of the path sways the
    /// same way whenever the body passes over it, so the body slides along an S laid on
    /// the floor, and stands still in it when the snake stops.
    struct Sway: Equatable {
        var amplitude = Double.zero
        var wavelength = Fraction.whole
        var crawled = Double.zero

        static let none = Sway()

        /// Metres to the side of the point `behind` metres back along the body from the
        /// head.
        func shift(behind: Double) -> Double {
            guard amplitude > .zero, wavelength > .zero else { return .zero }
            return amplitude * sin(Geometry.bothSides * .pi * (crawled - behind) / wavelength)
        }

        /// How much the shift changes for each metre forward at the head: which way the
        /// head points across its line.
        var slopeAtHead: Double {
            guard amplitude > .zero, wavelength > .zero else { return .zero }
            let wave = Geometry.bothSides * .pi / wavelength
            return amplitude * wave * cos(wave * crawled)
        }
    }

    /// The level direction square to a line running `tangent`, to the side a sway
    /// shifts to; none where the line runs straight up or down.
    static func side(of tangent: SIMD3<Double>) -> SIMD3<Double> {
        let across = simd_cross(SIMD3(.zero, Fraction.whole, .zero), tangent)
        let level = SIMD3(across.x, .zero, across.z)
        return simd_length(level) > SnakeShape.samePoint ? simd_normalize(level) : .zero
    }

    /// The most triangles a body through a tail of `points` may take (FR-VIEW-250).
    static func ceiling(points: Int) -> Int { SnakeBodyCeiling.perPoint * points + SnakeBodyCeiling.besides }

    /// The body round a line through `head` and then `tail`, head first, of `radius`,
    /// swollen where a meal is passing along it (FR-VIEW-280).
    ///
    /// Swaying, each point of the line is shifted to the side of it by the sway there
    /// (FR-VIEW-330), measured along the line it was before; the rings follow the
    /// shifted line.
    static func tube(head: SIMD3<Double>, tail: [SIMD3<Double>], radius: Double,
                     lumps: [Digestion.Lump] = [], sway: Sway = .none) -> SnakeBody {
        let spine = swayed(line(through: [head] + tail), by: sway)
        let tangents = directions(along: spine)
        let length = spine.lengths.last ?? .zero
        let radii = spine.lengths.map { radius * profile(at: $0, of: length) * swelling(at: $0, by: lumps) }
        // Resting on the surface: the line is lifted by the tube's own radius there.
        let centres = zip(spine.points, radii).map { $0 + SIMD3(.zero, $1, .zero) }
        let across = frames(along: tangents)

        var rings: [Ring] = []
        guard let firstCentre = centres.first, let firstAcross = across.first, let firstTangent = tangents.first,
              let lastCentre = centres.last, let lastAcross = across.last, let lastTangent = tangents.last,
              let firstRadius = radii.first, let lastRadius = radii.last else { return SnakeBody() }
        // The head's end, rounded off ahead of the first ring: the line runs from the
        // head towards the tail, so ahead of the head is against it.
        rings += end(at: firstCentre, tangent: firstTangent, facing: -firstTangent, across: firstAcross,
                     radius: firstRadius, along: .zero, outward: false)
        for index in centres.indices {
            rings.append(Ring(centre: centres[index], across: across[index],
                              up: simd_cross(tangents[index], across[index]), radius: radii[index],
                              facing: .zero, along: spine.lengths[index] + firstRadius))
        }
        rings += end(at: lastCentre, tangent: lastTangent, facing: lastTangent, across: lastAcross,
                     radius: lastRadius, along: length + firstRadius, outward: true)
        return stitch(rings)
    }

    // MARK: - The line

    private struct Line { var points: [SIMD3<Double>] = []; var lengths: [Double] = [] }

    /// The points given, one of any two that coincide, curved between them through
    /// the rings between points by a Catmull-Rom curve, which passes through every
    /// point it is given; with the length along it at each.
    private static func line(through given: [SIMD3<Double>]) -> Line {
        var points: [SIMD3<Double>] = []
        for point in given where points.last.map({ simd_distance($0, point) > SnakeShape.samePoint }) ?? true {
            points.append(point)
        }
        var line = Line()
        guard points.count > Distances.oneMore else {
            line.points = points
            line.lengths = points.map { _ in .zero }
            return line
        }
        func at(_ index: Int) -> SIMD3<Double> { points[min(max(index, .zero), points.count - Distances.oneMore)] }
        for index in Int.zero..<(points.count - Distances.oneMore) {
            let (p0, p1, p2, p3) = (at(index - 1), at(index), at(index + 1), at(index + 2))
            for step in Int.zero..<SnakeShape.ringsBetweenPoints {
                line.points.append(catmullRom(p0, p1, p2, p3, Double(step) / Double(SnakeShape.ringsBetweenPoints)))
            }
        }
        line.points.append(at(points.count - Distances.oneMore))
        var walked = Double.zero
        for (index, point) in line.points.enumerated() {
            if index > .zero { walked += simd_distance(line.points[index - 1], point) }
            line.lengths.append(walked)
        }
        return line
    }

    /// The line the body is drawn round, head first, and how far along it each point
    /// lies measured before the sway: what a test reads of the sway (FR-VIEW-330).
    static func centreLine(head: SIMD3<Double>, tail: [SIMD3<Double>],
                           sway: Sway = .none) -> (points: [SIMD3<Double>], lengths: [Double]) {
        let spine = swayed(line(through: [head] + tail), by: sway)
        return (spine.points, spine.lengths)
    }

    /// Each point of a line shifted to the side of it by the sway there, the lengths
    /// kept as they were before.
    private static func swayed(_ line: Line, by sway: Sway) -> Line {
        guard sway.amplitude > .zero else { return line }
        let straight = directions(along: line)
        var result = line
        result.points = line.points.indices.map { index in
            line.points[index] + side(of: straight[index]) * sway.shift(behind: line.lengths[index])
        }
        return result
    }

    private static func catmullRom(_ p0: SIMD3<Double>, _ p1: SIMD3<Double>, _ p2: SIMD3<Double>,
                                   _ p3: SIMD3<Double>, _ t: Double) -> SIMD3<Double> {
        let t2 = t * t, t3 = t2 * t
        let a = p1 * CatmullRom.two
        let b = (p2 - p0) * t
        let c = (p0 * CatmullRom.two - p1 * CatmullRom.five + p2 * CatmullRom.four - p3) * t2
        let d = (p1 * CatmullRom.three - p0 - p2 * CatmullRom.three + p3) * t3
        return (a + b + c + d) * Geometry.half
    }

    /// Which way the line runs at each point, head towards tail.
    private static func directions(along line: Line) -> [SIMD3<Double>] {
        let points = line.points
        guard points.count > Distances.oneMore else { return points.map { _ in SnakeShape.restingDirection } }
        return points.indices.map { index in
            let before = points[max(index - 1, .zero)], after = points[min(index + 1, points.count - 1)]
            let way = after - before
            return simd_length(way) > SnakeShape.samePoint ? simd_normalize(way) : SnakeShape.restingDirection
        }
    }

    /// A direction across the line at each point: level with the ground at the head,
    /// then carried along from each ring to the next, square to the line.
    private static func frames(along tangents: [SIMD3<Double>]) -> [SIMD3<Double>] {
        var across: [SIMD3<Double>] = []
        for tangent in tangents {
            let previous = across.last ?? simd_cross(tangent, SIMD3(.zero, Fraction.whole, .zero))
            var carried = previous - tangent * simd_dot(previous, tangent)
            if simd_length(carried) < SnakeShape.samePoint {
                carried = simd_cross(tangent, SIMD3(Fraction.whole, .zero, .zero))
            }
            if simd_length(carried) < SnakeShape.samePoint {
                carried = simd_cross(tangent, SIMD3(.zero, .zero, Fraction.whole))
            }
            across.append(simd_normalize(carried))
        }
        return across
    }

    /// The body's radius as a share of the full one, `along` metres from the head on a
    /// body `length` long: the head's width at the head, easing to the body's over the
    /// head's length (FR-VIEW-260); whole; then narrowing over the last stretch to the
    /// tip's share.
    static func profile(at along: Double, of length: Double) -> Double {
        func eased(_ t: Double) -> Double {
            let t = min(max(t, .zero), Fraction.whole)
            return t * t * (SmoothStep.three - SmoothStep.two * t)
        }
        let head = Fraction.whole + (SnakeShape.headShare - Fraction.whole) * (Fraction.whole - eased(along / SnakeShape.headLength))
        let start = length * (Fraction.whole - SnakeShape.taperShare)
        guard length > .zero, along > start else { return head }
        return head * (Fraction.whole - (Fraction.whole - SnakeShape.tipShare) * eased((along - start) / (length - start)))
    }

    /// How much wider the body is `along` metres from the head for the meals passing
    /// along it: each a bell round its middle, as tall as its size allows.
    static func swelling(at along: Double, by lumps: [Digestion.Lump]) -> Double {
        lumps.reduce(Fraction.whole) { total, lump in
            let off = (along - lump.along) / SnakeLump.width
            return total + SnakeLump.swell * lump.size * exp(-off * off)
        }
    }

    // MARK: - The rings

    private struct Ring {
        var centre: SIMD3<Double>
        var across: SIMD3<Double>
        var up: SIMD3<Double>
        var radius: Double
        /// How much of the normal leans along the line, at an end's rounding.
        var facing: SIMD3<Double>
        var along: Double
    }

    /// The rings that round off an end: a quarter circle out from the end's ring, the
    /// last of them the end's point. Their frame is the line's there, whichever way the
    /// end faces, so that the triangles face out at both ends.
    private static func end(at centre: SIMD3<Double>, tangent: SIMD3<Double>, facing: SIMD3<Double>,
                            across: SIMD3<Double>, radius: Double, along: Double, outward: Bool) -> [Ring] {
        let up = simd_cross(tangent, across)
        let angles = (Distances.oneMore...SnakeShape.endRings).map {
            Double($0) / Double(SnakeShape.endRings) * .pi * Geometry.half
        }
        let rings = angles.map { angle in
            Ring(centre: centre + facing * (radius * sin(angle)), across: across, up: up,
                 radius: radius * cos(angle), facing: facing * sin(angle),
                 along: outward ? along + radius * sin(angle) : along + radius * (Fraction.whole - sin(angle)))
        }
        // The head's end is laid out from its point inwards, so that the rings run
        // head to tail throughout.
        return outward ? rings : rings.reversed()
    }

    private static func stitch(_ rings: [Ring]) -> SnakeBody {
        var body = SnakeBody()
        let columns = SnakeShape.sides + Distances.oneMore
        for ring in rings {
            let lean = simd_length(ring.facing)
            for column in Int.zero..<columns {
                let angle = Double(column) / Double(SnakeShape.sides) * .pi * Geometry.bothSides
                let round = ring.across * cos(angle) + ring.up * sin(angle)
                let normal = simd_normalize(round * (Fraction.whole - lean * lean).squareRoot() + ring.facing)
                body.positions.append(SIMD3<Float>(ring.centre + round * ring.radius))
                body.normals.append(SIMD3<Float>(normal))
                body.surface.append(SIMD2(Float(ring.along), Float(Double(column) / Double(SnakeShape.sides))))
            }
        }
        for ring in Int.zero..<max(rings.count - Distances.oneMore, .zero) {
            for column in Int.zero..<SnakeShape.sides {
                let a = UInt32(ring * columns + column), b = a + 1
                let c = a + UInt32(columns), d = c + 1
                body.indices += [a, b, c, b, d, c]
            }
        }
        return body
    }
}

/// Catmull-Rom's coefficients: the curve is half of 2p1 + (p2 − p0)t
/// + (2p0 − 5p1 + 4p2 − p3)t² + (3p1 − p0 − 3p2 + p3)t³.
private enum CatmullRom {
    static let two = 2.0
    static let three = 3.0
    static let four = 4.0
    static let five = 5.0
}

/// FR-VIEW-250's ceiling: triangles for each point of the tail, and besides.
enum SnakeBodyCeiling {
    static let perPoint = 64
    static let besides = 256
}
