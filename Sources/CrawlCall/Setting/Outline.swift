// The edge of a setting drawn along the map's outline (FR-MAP-200), as data a test can
// read: a signed distance to the edge over a fine grid, and the flat surfaces and the
// walls cut from it.
//
// The edge is the outline of floor 0 grown by a margin — so that it lies outside every
// cell of the map — and closed by a radius, so that the grid's steps and narrow notches
// round off: a disc of the margin rolled round the outside rounds its corners, and a
// disc of the rounding rolled round the inside fills and rounds its hollows. On the
// grid that is two thresholds of distances (ADR-0034).
//
// Surfaces are cut from the field by marching squares: where a square of samples lies
// wholly inside, it is part of a strip along its row; where the edge crosses it, the
// part inside, with the edge placed between the samples by the field's values, so the
// edge is smooth to a fraction of the grid's step rather than stepped by it.
//
// implements: FR-MAP-200, FR-MAP-170, FR-GREENHOLM-010, FR-MAP-270
import Foundation
import simd

/// Triangles in world metres, with a normal for every vertex.
struct Mesh: Equatable {
    var positions: [SIMD3<Double>] = []
    var normals: [SIMD3<Double>] = []
    var indices: [UInt32] = []
    /// For a sea floor, how far down its slope each vertex lies, 0 at the edge and 1
    /// at the full depth (FR-MAP-270); empty for every other surface.
    var shares: [Double] = []

    var isEmpty: Bool { indices.isEmpty }

    mutating func triangle(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>, normal: SIMD3<Double>) {
        let first = UInt32(positions.count)
        positions += [a, b, c]
        normals += [normal, normal, normal]
        indices += (first..<first + UInt32(Square.triangle)).map { $0 }
    }
}

/// The signed distance to a setting's edge over the ground around a map: positive
/// inside the edge, negative outside it, in metres.
struct Outline: Equatable {
    let grid: SampleGrid
    let signed: [Double]
    /// For each sample, whether it lies over a cell with a floor below floor 0 — a
    /// basement — which the setting's ground must leave open (FR-MAP-170).
    let overBasement: [Bool]

    /// The edge round a set of cells of floor 0, `cellSize` metres each, grown by
    /// `margin` and rounded by `rounding`, over a grid reaching `reach` metres beyond it.
    static func around(_ cells: Set<PieceIndex.Cell>, basement: Set<PieceIndex.Cell>, cellSize: Double,
                       margin: Double, rounding: Double, reach: Double) -> Outline? {
        guard !cells.isEmpty, cellSize > .zero else { return nil }
        let xs = cells.map(\.x), zs = cells.map(\.z)
        guard let lowX = xs.min(), let highX = xs.max(), let lowZ = zs.min(), let highZ = zs.max() else { return nil }
        let half = cellSize * Geometry.half
        let beyond = margin + rounding + reach
        let low = SIMD2(Double(lowX) * cellSize - half - beyond, Double(lowZ) * cellSize - half - beyond)
        let high = SIMD2(Double(highX) * cellSize + half + beyond, Double(highZ) * cellSize + half + beyond)
        let grid = SampleGrid(covering: low, high, step: OutlineGrid.step)

        func cell(of point: SIMD2<Double>) -> PieceIndex.Cell {
            PieceIndex.Cell(x: Int((point.x / cellSize).rounded()), z: Int((point.y / cellSize).rounded()))
        }
        var footprint = [Bool](repeating: false, count: grid.count)
        var underground = footprint
        for row in Int.zero..<grid.height {
            for column in Int.zero..<grid.width {
                let here = cell(of: grid.point(column, row))
                footprint[grid.index(column, row)] = cells.contains(here)
                underground[grid.index(column, row)] = basement.contains(here)
            }
        }
        // Grown by the margin and the rounding, then shrunk by the rounding: the
        // footprint grown by the margin, with its hollows filled round.
        let fromFootprint = DistanceField.distance(to: footprint, on: grid)
        let grown = fromFootprint.map { $0 <= margin + rounding }
        let fromOutsideGrown = DistanceField.distance(to: grown.map { !$0 }, on: grid)
        let island = fromOutsideGrown.map { $0 >= rounding }
        let outside = DistanceField.distance(to: island, on: grid)
        let inside = DistanceField.distance(to: island.map { !$0 }, on: grid)
        let signed = zip(inside, outside).map { $0.0 > .zero ? $0.0 : -$0.1 }
        // The opening over a basement grown by a step of the grid: an edge cut between
        // samples lies up to a step beyond the last sample, and without it a sliver of
        // ground would reach into the basement's cells.
        let opening = DistanceField.distance(to: underground, on: grid).map { $0 <= grid.step }
        return Outline(grid: grid, signed: signed, overBasement: opening)
    }

    /// A field's value at the sample nearest a point on the ground; outside the grid,
    /// the value at its nearest edge.
    func value(of field: [Double], at point: SIMD2<Double>) -> Double {
        let place = ((point - grid.origin) / grid.step).rounded(.toNearestOrAwayFromZero)
        let column = min(max(Int(place.x), .zero), grid.width - Distances.oneMore)
        let row = min(max(Int(place.y), .zero), grid.height - Distances.oneMore)
        return field[grid.index(column, row)]
    }

    /// The field for "at least `level` inside the edge, and not over a basement".
    func region(atLeast level: Double, sparingBasements: Bool) -> [Double] {
        zip(signed, overBasement).map { value, basement in
            sparingBasements && basement ? -.infinity : value - level
        }
    }

    // MARK: - Surfaces and walls

    /// A flat surface at `height` wherever `field` is not negative: whole squares in
    /// strips along their rows, and the part inside of every square the edge crosses.
    static func surface(where field: [Double], on grid: SampleGrid, height: Double) -> Mesh {
        var mesh = Mesh()
        let up = SIMD3(Fraction.none, Fraction.whole, Fraction.none)
        func at(_ p: SIMD2<Double>) -> SIMD3<Double> { SIMD3(p.x, height, p.y) }
        for row in Int.zero..<(grid.height - Distances.oneMore) {
            var runStart: Int?
            for column in Int.zero..<grid.width {
                let whole = column < grid.width - Distances.oneMore && corners(column, row, field, grid).allSatisfy { $0 >= .zero }
                if whole {
                    if runStart == nil { runStart = column }
                    continue
                }
                if let start = runStart {
                    let a = grid.point(start, row), b = grid.point(column, row)
                    let c = grid.point(column, row + Distances.oneMore), d = grid.point(start, row + Distances.oneMore)
                    mesh.triangle(at(a), at(d), at(c), normal: up)
                    mesh.triangle(at(a), at(c), at(b), normal: up)
                    runStart = nil
                }
                guard column < grid.width - Distances.oneMore else { continue }
                let polygon = inside(column, row, field, grid)
                guard polygon.count >= Square.triangle else { continue }
                for k in Distances.oneMore..<(polygon.count - Distances.oneMore) {
                    mesh.triangle(at(polygon[Int.zero].point), at(polygon[k + Distances.oneMore].point),
                                  at(polygon[k].point), normal: up)
                }
            }
        }
        return mesh
    }

    /// The floor under the water (FR-MAP-270): a height field over the grid, every
    /// `stride` samples, just under the water at `top` where the signed distance
    /// says the edge is `edge` metres out, falling smoothly to `bottom` over `width`
    /// metres beyond it, and level there. Only where it can be seen: squares with a
    /// corner beyond the edge, less one square, so that it reaches in under the shore
    /// and leaves no gap; never under the island, where a basement may be open.
    static func floor(under outline: Outline, edge: Double, width: Double, top: Double, bottom: Double,
                      stride: Int) -> Mesh {
        let grid = outline.grid
        let stride = max(stride, Distances.oneMore)
        let columns = (grid.width - Distances.oneMore) / stride + Distances.oneMore
        let rows = (grid.height - Distances.oneMore) / stride + Distances.oneMore
        let spacing = grid.step * Double(stride)
        func sample(_ column: Int, _ row: Int) -> Double {
            outline.signed[grid.index(column * stride, row * stride)]
        }
        func share(_ column: Int, _ row: Int) -> Double {
            let beyond = -sample(column, row) - edge
            guard width > .zero else { return beyond > .zero ? Fraction.whole : Fraction.none }
            let t = min(max(beyond / width, Fraction.none), Fraction.whole)
            return t * t * (SmoothStep.three - SmoothStep.two * t)
        }
        var shares = [Double](repeating: .zero, count: columns * rows)
        var heights = shares
        for row in Int.zero..<rows {
            for column in Int.zero..<columns {
                let s = share(column, row)
                shares[row * columns + column] = s
                heights[row * columns + column] = top + (bottom - top) * s
            }
        }
        func height(_ column: Int, _ row: Int) -> Double {
            heights[min(max(row, .zero), rows - Distances.oneMore) * columns
                    + min(max(column, .zero), columns - Distances.oneMore)]
        }
        var mesh = Mesh()
        var index = [Int](repeating: -1, count: columns * rows)
        func vertex(_ column: Int, _ row: Int) -> UInt32 {
            let at = row * columns + column
            if index[at] < .zero {
                index[at] = mesh.positions.count
                let p = grid.point(column * stride, row * stride)
                mesh.positions.append(SIMD3(p.x, heights[at], p.y))
                // Central differences over the height field, one step either side.
                let next = Distances.oneMore
                let across = (height(column + next, row) - height(column - next, row)) / (Geometry.bothSides * spacing)
                let down = (height(column, row + next) - height(column, row - next)) / (Geometry.bothSides * spacing)
                mesh.normals.append(simd_normalize(SIMD3(-across, Fraction.whole, -down)))
                mesh.shares.append(shares[at])
            }
            return UInt32(index[at])
        }
        for row in Int.zero..<(rows - Distances.oneMore) {
            for column in Int.zero..<(columns - Distances.oneMore) {
                let next = Distances.oneMore
                let nearest = [sample(column, row), sample(column + next, row),
                               sample(column, row + next), sample(column + next, row + next)].min() ?? .infinity
                guard nearest < -edge + spacing else { continue }
                let a = vertex(column, row), b = vertex(column + next, row)
                let c = vertex(column + next, row + next), d = vertex(column, row + next)
                // Wound as `surface` winds its squares, so that the floor faces up.
                mesh.indices += [a, d, c, a, c, b]
            }
        }
        return mesh
    }

    /// A level rectangle at `height`, facing up, every vertex at `share` down the
    /// floor's slope: the floor and the water beyond the grid (FR-MAP-270).
    static func level(_ rect: GroundRect, height: Double, share: Double) -> Mesh {
        let up = SIMD3(Fraction.none, Fraction.whole, Fraction.none)
        let low = rect.lowest, high = rect.highest
        let a = SIMD3(low.x, height, low.y), b = SIMD3(high.x, height, low.y)
        let c = SIMD3(high.x, height, high.y), d = SIMD3(low.x, height, high.y)
        var mesh = Mesh()
        mesh.triangle(a, d, c, normal: up)
        mesh.triangle(a, c, b, normal: up)
        mesh.shares = [Double](repeating: share, count: mesh.positions.count)
        return mesh
    }

    /// Vertical walls along where `field` crosses zero, from `top` down to `bottom`,
    /// facing the side where the field is negative.
    static func wall(along field: [Double], on grid: SampleGrid, top: Double, bottom: Double) -> Mesh {
        var mesh = Mesh()
        for row in Int.zero..<(grid.height - Distances.oneMore) {
            for column in Int.zero..<(grid.width - Distances.oneMore) {
                let polygon = inside(column, row, field, grid)
                guard polygon.contains(where: { !$0.isCorner }) else { continue }
                let values = corners(column, row, field, grid)
                // Towards falling values: the gradient over the square, reversed.
                let across = ((values[Square.across] + values[Square.diagonal])
                              - (values[Square.origin] + values[Square.down])) * Geometry.half
                let down = ((values[Square.down] + values[Square.diagonal])
                            - (values[Square.origin] + values[Square.across])) * Geometry.half
                let length = (across * across + down * down).squareRoot()
                guard length > .zero else { continue }
                let outward = SIMD3(-across / length, Fraction.none, -down / length)
                for (k, vertex) in polygon.enumerated() where !vertex.isCorner {
                    let next = polygon[(k + Distances.oneMore) % polygon.count]
                    guard !next.isCorner else { continue }
                    let a = vertex.point, b = next.point
                    let aTop = SIMD3(a.x, top, a.y), bTop = SIMD3(b.x, top, b.y)
                    let aBottom = SIMD3(a.x, bottom, a.y), bBottom = SIMD3(b.x, bottom, b.y)
                    mesh.triangle(aTop, aBottom, bBottom, normal: outward)
                    mesh.triangle(aTop, bBottom, bTop, normal: outward)
                }
            }
        }
        return mesh
    }

    /// The four samples of a square, in order round it: its corner, across, across
    /// and down, down.
    private static func corners(_ column: Int, _ row: Int, _ field: [Double], _ grid: SampleGrid) -> [Double] {
        let next = Distances.oneMore
        return [field[grid.index(column, row)], field[grid.index(column + next, row)],
                field[grid.index(column + next, row + next)], field[grid.index(column, row + next)]]
    }

    /// The part of a square where the field is not negative, as its vertices in order
    /// round the square: the corners inside, and between an inside and an outside
    /// corner the point the field crosses zero, placed by its values. Being points on
    /// the square's boundary in order round it, it is convex.
    private static func inside(_ column: Int, _ row: Int, _ field: [Double], _ grid: SampleGrid)
        -> [(point: SIMD2<Double>, isCorner: Bool)] {
        let next = Distances.oneMore
        let points = [grid.point(column, row), grid.point(column + next, row),
                      grid.point(column + next, row + next), grid.point(column, row + next)]
        let values = corners(column, row, field, grid)
        var polygon: [(point: SIMD2<Double>, isCorner: Bool)] = []
        for k in points.indices {
            let j = (k + next) % points.count
            if values[k] >= .zero { polygon.append((points[k], true)) }
            if (values[k] >= .zero) != (values[j] >= .zero) {
                let a = values[k].isFinite ? values[k] : (values[k] > .zero ? Distances.far : -Distances.far)
                let b = values[j].isFinite ? values[j] : (values[j] > .zero ? Distances.far : -Distances.far)
                let t = a / (a - b)
                polygon.append((points[k] + (points[j] - points[k]) * t, false))
            }
        }
        return polygon
    }
}
