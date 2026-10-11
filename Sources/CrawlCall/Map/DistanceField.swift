// Distances over a grid of samples on the ground: how far each sample is from the
// nearest sample of a set. A setting's edge is drawn from them (FR-MAP-200): the map's
// outline grown, closed and rounded is a question of distances, and asked on a fine
// grid it is answered for every point at once.
//
// The exact Euclidean distance transform of Felzenszwalb and Huttenlocher ("Distance
// Transforms of Sampled Functions", Theory of Computing 8, 2012): a one-dimensional
// transform along every row, then along every column of the result, each in time
// linear in its length, by the lower envelope of the parabolas rooted at the samples.
//
// file implements: FR-MAP-200
import Foundation

/// A grid of samples over the ground: `width` by `height` of them, `step` metres
/// apart, the first at `origin`, x across and z down the rows.
struct SampleGrid: Equatable {
    let origin: SIMD2<Double>
    let step: Double
    let width: Int
    let height: Int

    var count: Int { width * height }
    func index(_ column: Int, _ row: Int) -> Int { row * width + column }
    func point(_ column: Int, _ row: Int) -> SIMD2<Double> {
        origin + SIMD2(Double(column), Double(row)) * step
    }

    /// A grid covering the rectangle from `low` to `high`, a whole number of steps
    /// across, reaching at least to its far edges.
    init(covering low: SIMD2<Double>, _ high: SIMD2<Double>, step: Double) {
        self.origin = low
        self.step = step
        self.width = Int(((high.x - low.x) / step).rounded(.up)) + Distances.oneMore
        self.height = Int(((high.y - low.y) / step).rounded(.up)) + Distances.oneMore
    }
}

enum DistanceField {
    /// Metres from every sample of the grid to the nearest sample where `mask` is true;
    /// infinite everywhere where it is true nowhere.
    static func distance(to mask: [Bool], on grid: SampleGrid) -> [Double] {
        precondition(mask.count == grid.count, "a mask is one value per sample")
        guard mask.contains(true) else { return [Double](repeating: .infinity, count: grid.count) }
        // Squared distances in samples: zero on the set, "infinity" off it.
        var squared = mask.map { $0 ? Double.zero : Distances.far }
        var line = [Double](repeating: .zero, count: max(grid.width, grid.height))
        var result = line
        for row in Int.zero..<grid.height {
            for column in Int.zero..<grid.width { line[column] = squared[grid.index(column, row)] }
            transform(line, count: grid.width, into: &result)
            for column in Int.zero..<grid.width { squared[grid.index(column, row)] = result[column] }
        }
        for column in Int.zero..<grid.width {
            for row in Int.zero..<grid.height { line[row] = squared[grid.index(column, row)] }
            transform(line, count: grid.height, into: &result)
            for row in Int.zero..<grid.height { squared[grid.index(column, row)] = result[row] }
        }
        return squared.map { $0.squareRoot() * grid.step }
    }

    /// The one-dimensional squared transform of `f` over its first `count` values:
    /// for each q, the least of (q − p)² + f(p) over every p.
    private static func transform(_ f: [Double], count: Int, into d: inout [Double]) {
        var roots = [Int](repeating: .zero, count: count)       // where each parabola is rooted
        var bounds = [Double](repeating: .zero, count: count + Distances.oneMore)
        var k = Int.zero
        roots[Int.zero] = Int.zero
        bounds[Int.zero] = -.infinity
        bounds[Distances.oneMore] = .infinity
        func meeting(_ q: Int, _ r: Int) -> Double {
            let a = f[q] + Double(q * q), b = f[r] + Double(r * r)
            return (a - b) / (Geometry.bothSides * Double(q - r))
        }
        for q in Distances.oneMore..<max(count, Distances.oneMore) where q < count {
            var s = meeting(q, roots[k])
            while s <= bounds[k] {
                k -= Distances.oneMore
                s = meeting(q, roots[k])
            }
            k += Distances.oneMore
            roots[k] = q
            bounds[k] = s
            bounds[k + Distances.oneMore] = .infinity
        }
        k = Int.zero
        for q in Int.zero..<count {
            while bounds[k + Distances.oneMore] < Double(q) { k += Distances.oneMore }
            let gap = Double(q - roots[k])
            d[q] = gap * gap + f[roots[k]]
        }
    }
}
